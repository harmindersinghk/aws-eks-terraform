# Memory Fix for Currency and Payment Services

## Issue Description

The currencyservice and paymentservice pods in the Online Boutique application are experiencing frequent restarts due to Out of Memory (OOM) kills. The containers are being terminated by Kubernetes when they exceed their memory limits of 128Mi.

**Evidence:**
- Pod restart count: 3+ for both services
- Container termination reason: "OOMKilled"
- Exit code: 137 (128 + 9, indicating SIGKILL due to OOM)

## Solution

This branch increases the memory resources for both services:

1. **currencyService**:
   - Memory request: 64Mi → 128Mi
   - Memory limit: 128Mi → 256Mi

2. **paymentService**:
   - Memory request: 64Mi → 128Mi
   - Memory limit: 128Mi → 256Mi

## Implementation

The fix is implemented through:

1. A custom values file (`values-memory-fix.yaml`) that overrides the memory settings
2. A shell script (`fix-memory-issues.sh`) that applies these changes to the running deployment

## How to Apply

Run the provided script:

```bash
./fix-memory-issues.sh
```

This will:
- Identify the namespace where the services are deployed
- Apply the memory fixes using Helm
- Wait for the deployments to roll out
- Display the new resource limits

## Verification

After applying the fix, verify that the pods are no longer restarting:

```bash
kubectl get pods -n app | grep -E 'currency|payment'
```

The restart count should stop increasing, and the pods should remain in the Running state.

## Additional Recommendations

1. Monitor the actual memory usage of these services to determine if further adjustments are needed
2. Consider investigating potential memory leaks in the application code
3. Set up alerts for container restarts and OOM events to catch similar issues early
