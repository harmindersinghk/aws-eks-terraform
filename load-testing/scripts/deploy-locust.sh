#!/bin/bash

# Deploy Locust Load Testing Infrastructure
# This script deploys Locust master and worker pods to perform load testing on Online Boutique

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="load-testing"
CLUSTER_NAME="eks-cluster"
REGION="eu-west-1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$(dirname "$SCRIPT_DIR")/k8s-manifests"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if we can connect to the cluster
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        log_info "Make sure you have run: aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION"
        exit 1
    fi
    
    # Check if Online Boutique is deployed
    if ! kubectl get namespace app &> /dev/null; then
        log_error "Online Boutique app namespace not found"
        log_info "Please deploy the Online Boutique application first"
        exit 1
    fi
    
    if ! kubectl get service frontend-external -n app &> /dev/null; then
        log_error "Online Boutique frontend service not found"
        log_info "Please ensure the Online Boutique application is properly deployed"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

deploy_locust() {
    log_info "Deploying Locust load testing infrastructure..."
    
    # Apply manifests in order
    log_info "Creating namespace and RBAC..."
    kubectl apply -f "$MANIFESTS_DIR/namespace.yaml"
    
    log_info "Creating ConfigMap..."
    kubectl apply -f "$MANIFESTS_DIR/locust-configmap.yaml"
    
    log_info "Deploying Locust master..."
    kubectl apply -f "$MANIFESTS_DIR/locust-master.yaml"
    
    log_info "Deploying Locust workers..."
    kubectl apply -f "$MANIFESTS_DIR/locust-worker.yaml"
    
    log_success "Locust manifests applied successfully"
}

wait_for_deployment() {
    log_info "Waiting for deployments to be ready..."
    
    # Wait for master deployment
    log_info "Waiting for Locust master to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/locust-master -n $NAMESPACE
    
    # Wait for worker deployment
    log_info "Waiting for Locust workers to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/locust-worker -n $NAMESPACE
    
    log_success "All deployments are ready"
}

get_access_info() {
    log_info "Getting access information..."
    
    # Get LoadBalancer URL
    log_info "Waiting for LoadBalancer to get external IP..."
    
    # Wait up to 5 minutes for external IP
    for i in {1..30}; do
        EXTERNAL_IP=$(kubectl get service locust-master -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        if [ -n "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "null" ]; then
            break
        fi
        log_info "Waiting for external IP... (attempt $i/30)"
        sleep 10
    done
    
    if [ -n "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "null" ]; then
        log_success "Locust Web UI is available at: http://$EXTERNAL_IP:8089"
        echo ""
        echo "=== LOCUST ACCESS INFORMATION ==="
        echo "Web UI URL: http://$EXTERNAL_IP:8089"
        echo "Target Host: http://frontend-external.app.svc.cluster.local"
        echo "Default Users: 50"
        echo "Default Spawn Rate: 2 users/second"
        echo "Default Run Time: 10 minutes"
        echo ""
        echo "=== QUICK START ==="
        echo "1. Open the Web UI URL in your browser"
        echo "2. Adjust the number of users and spawn rate if needed"
        echo "3. Click 'Start swarming' to begin the load test"
        echo "4. Monitor the results in real-time"
        echo ""
    else
        log_warning "Could not get external IP for LoadBalancer"
        log_info "You can access Locust using port-forward:"
        echo "kubectl port-forward service/locust-master 8089:8089 -n $NAMESPACE"
        echo "Then open http://localhost:8089 in your browser"
    fi
}

show_status() {
    log_info "Current deployment status:"
    echo ""
    kubectl get pods -n $NAMESPACE -o wide
    echo ""
    kubectl get services -n $NAMESPACE
    echo ""
}

# Main execution
main() {
    log_info "Starting Locust deployment for Online Boutique load testing"
    
    check_prerequisites
    deploy_locust
    wait_for_deployment
    show_status
    get_access_info
    
    log_success "Locust deployment completed successfully!"
    log_info "You can monitor the deployment with: kubectl get pods -n $NAMESPACE -w"
}

# Handle script arguments
case "${1:-deploy}" in
    "deploy")
        main
        ;;
    "status")
        show_status
        ;;
    "cleanup")
        log_info "Cleaning up Locust deployment..."
        kubectl delete namespace $NAMESPACE --ignore-not-found=true
        log_success "Cleanup completed"
        ;;
    "logs")
        log_info "Showing Locust master logs..."
        kubectl logs -f deployment/locust-master -n $NAMESPACE
        ;;
    *)
        echo "Usage: $0 [deploy|status|cleanup|logs]"
        echo "  deploy  - Deploy Locust (default)"
        echo "  status  - Show deployment status"
        echo "  cleanup - Remove Locust deployment"
        echo "  logs    - Show Locust master logs"
        exit 1
        ;;
esac
