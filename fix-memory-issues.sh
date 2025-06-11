#!/bin/bash

# Script to apply memory fixes for currencyservice and paymentservice
# This script applies a values file with increased memory limits to the Helm release

set -e

echo "Applying memory fixes for currencyservice and paymentservice..."

# Get the current namespace where the app is deployed
NAMESPACE=$(kubectl get deployment currencyservice -o jsonpath='{.metadata.namespace}')
echo "Found services in namespace: $NAMESPACE"

# Apply the Helm upgrade with our values file
echo "Upgrading Helm release with increased memory limits..."
helm upgrade --namespace $NAMESPACE onlineboutique ./online-boutique-tf/helm-chart -f ./online-boutique-tf/helm-chart/values-memory-fix.yaml

echo "Waiting for deployments to roll out..."
kubectl rollout status deployment/currencyservice -n $NAMESPACE
kubectl rollout status deployment/paymentservice -n $NAMESPACE

echo "Memory fixes applied successfully!"
echo "New resource limits:"
echo "currencyService: 128Mi request, 256Mi limit"
echo "paymentService: 128Mi request, 256Mi limit"
