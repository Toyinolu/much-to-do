#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-muchtodo-cluster}"
NAMESPACE="muchtodo"

echo "==> Deleting all resources in namespace '${NAMESPACE}'..."
kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true

echo "==> Removing NGINX Ingress Controller..."
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml \
  --ignore-not-found=true 2>/dev/null || true

echo "==> Deleting Kind cluster: ${CLUSTER_NAME}"
kind delete cluster --name "${CLUSTER_NAME}"

echo "==> Cleanup complete."
