#!/bin/bash

set -euo pipefail

NAMESPACE="${NAMESPACE:-load-testing}"
SERVICE_NAME="${SERVICE_NAME:-locust-master}"
LOCAL_PORT="${LOCAL_PORT:-8089}"
TARGET_HOST="${TARGET_HOST:-http://frontend-external.app.svc.cluster.local}"
ARTIFACT_DIR="${ARTIFACT_DIR:-load-testing-artifacts}"
USERS="${USERS:?USERS is required}"
SPAWN_RATE="${SPAWN_RATE:?SPAWN_RATE is required}"
RUN_TIME="${RUN_TIME:?RUN_TIME is required}"
AUTO_CLEANUP="${AUTO_CLEANUP:-true}"

PORT_FORWARD_PID=""

log() {
    echo "[loadtest] $*"
}

cleanup() {
    local exit_code=$?

    if [[ -n "$PORT_FORWARD_PID" ]] && kill -0 "$PORT_FORWARD_PID" 2>/dev/null; then
        kill "$PORT_FORWARD_PID" 2>/dev/null || true
        wait "$PORT_FORWARD_PID" 2>/dev/null || true
    fi

    if [[ "$AUTO_CLEANUP" == "true" ]]; then
        log "Cleaning up namespace $NAMESPACE"
        kubectl delete namespace "$NAMESPACE" --ignore-not-found=true
    fi

    exit "$exit_code"
}

trap cleanup EXIT

duration_to_seconds() {
    local value="$1"

    if [[ "$value" =~ ^([0-9]+)([smhd]?)$ ]]; then
        local amount="${BASH_REMATCH[1]}"
        local unit="${BASH_REMATCH[2]}"

        case "$unit" in
            ""|"s") echo "$amount" ;;
            "m") echo $((amount * 60)) ;;
            "h") echo $((amount * 3600)) ;;
            "d") echo $((amount * 86400)) ;;
            *) return 1 ;;
        esac
        return 0
    fi

    return 1
}

wait_for_http() {
    local retries=30
    local delay=2

    for ((i = 1; i <= retries; i++)); do
        if curl --silent --fail "http://127.0.0.1:${LOCAL_PORT}/" >/dev/null; then
            return 0
        fi
        sleep "$delay"
    done

    return 1
}

download_file() {
    local pod_name="$1"
    local remote_path="$2"
    local output_name="$3"

    if kubectl exec -n "$NAMESPACE" "$pod_name" -- test -f "$remote_path"; then
        kubectl exec -n "$NAMESPACE" "$pod_name" -- cat "$remote_path" > "${ARTIFACT_DIR}/${output_name}"
        log "Saved ${ARTIFACT_DIR}/${output_name}"
    else
        log "Skipping missing artifact ${remote_path}"
    fi
}

log "Deploying Locust components"
./load-testing/scripts/deploy-locust.sh deploy

log "Waiting for Locust worker pods to register"
kubectl wait --for=jsonpath='{.status.ready}'=true --timeout=180s pod -l app=locust,role=worker -n "$NAMESPACE"

mkdir -p "$ARTIFACT_DIR"

log "Starting port-forward to ${SERVICE_NAME}:${LOCAL_PORT}"
kubectl port-forward -n "$NAMESPACE" "service/${SERVICE_NAME}" "${LOCAL_PORT}:8089" >"${ARTIFACT_DIR}/port-forward.log" 2>&1 &
PORT_FORWARD_PID=$!

if ! wait_for_http; then
    log "Locust UI did not become reachable"
    exit 1
fi

log "Starting load test: users=${USERS} spawn_rate=${SPAWN_RATE} run_time=${RUN_TIME}"
curl --silent --show-error --fail \
    -X POST "http://127.0.0.1:${LOCAL_PORT}/swarm" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "user_count=${USERS}" \
    --data-urlencode "spawn_rate=${SPAWN_RATE}" \
    --data-urlencode "host=${TARGET_HOST}" \
    > "${ARTIFACT_DIR}/swarm-response.json"

SECONDS_TO_RUN="$(duration_to_seconds "$RUN_TIME")"
sleep "$SECONDS_TO_RUN"

log "Stopping load test"
curl --silent --show-error --fail \
    -X GET "http://127.0.0.1:${LOCAL_PORT}/stop" \
    > "${ARTIFACT_DIR}/stop-response.txt"

sleep 10

MASTER_POD="$(kubectl get pods -n "$NAMESPACE" -l app=locust,role=master -o jsonpath='{.items[0].metadata.name}')"
kubectl get pods -n "$NAMESPACE" -o wide > "${ARTIFACT_DIR}/pods.txt"
kubectl get services -n "$NAMESPACE" > "${ARTIFACT_DIR}/services.txt"
kubectl logs -n "$NAMESPACE" "$MASTER_POD" > "${ARTIFACT_DIR}/locust-master.log"

download_file "$MASTER_POD" "/tmp/locust.log" "locust.log"
download_file "$MASTER_POD" "/tmp/report.html" "report.html"
download_file "$MASTER_POD" "/tmp/results_stats.csv" "results_stats.csv"
download_file "$MASTER_POD" "/tmp/results_stats_history.csv" "results_stats_history.csv"
download_file "$MASTER_POD" "/tmp/results_failures.csv" "results_failures.csv"
download_file "$MASTER_POD" "/tmp/results_exceptions.csv" "results_exceptions.csv"

curl --silent --show-error --fail "http://127.0.0.1:${LOCAL_PORT}/stats/requests" \
    > "${ARTIFACT_DIR}/stats-requests.json"
curl --silent --show-error --fail "http://127.0.0.1:${LOCAL_PORT}/exceptions" \
    > "${ARTIFACT_DIR}/exceptions.json"

log "Load test completed"
