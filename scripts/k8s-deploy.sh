#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-muchtodo-cluster}"
IMAGE_NAME="${IMAGE_NAME:-muchtodo-backend}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
NAMESPACE="muchtodo"

# 1. Create Kind cluster if it doesn't exist
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo "==> Kind cluster '${CLUSTER_NAME}' already exists, skipping creation."
else
  echo "==> Creating Kind cluster: ${CLUSTER_NAME}"
  kind create cluster --name "${CLUSTER_NAME}" --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
      - containerPort: 30080
        hostPort: 30080
        protocol: TCP
EOF
fi

# 2. Build the Docker image
echo "==> Building Docker image: ${IMAGE_NAME}:${IMAGE_TAG}"
docker build --tag "${IMAGE_NAME}:${IMAGE_TAG}" --file Dockerfile .

# 3. Load image into Kind cluster
echo "==> Loading image into Kind cluster..."
kind load docker-image "${IMAGE_NAME}:${IMAGE_TAG}" --name "${CLUSTER_NAME}"

# 4. Install NGINX Ingress Controller
echo "==> Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

echo "==> Waiting for ingress controller to be ready..."
sleep 10
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s

# 5. Apply manifests in order
echo "==> Applying Kubernetes manifests..."
kubectl apply -f kubernetes/namespace.yaml

kubectl apply -f kubernetes/mongodb/mongodb-secret.yaml
kubectl apply -f kubernetes/mongodb/mongodb-configmap.yaml
kubectl apply -f kubernetes/mongodb/mongodb-pvc.yaml
kubectl apply -f kubernetes/mongodb/mongodb-deployment.yaml
kubectl apply -f kubernetes/mongodb/mongodb-service.yaml

kubectl apply -f kubernetes/backend/backend-secret.yaml
kubectl apply -f kubernetes/backend/backend-configmap.yaml
kubectl apply -f kubernetes/backend/backend-deployment.yaml
kubectl apply -f kubernetes/backend/backend-service.yaml

kubectl apply -f kubernetes/ingress.yaml

# 6. Wait for deployments
echo "==> Waiting for MongoDB to be ready..."
kubectl rollout status deployment/mongodb -n "${NAMESPACE}" --timeout=120s

echo "==> Waiting for backend to be ready..."
kubectl rollout status deployment/muchtodo-backend -n "${NAMESPACE}" --timeout=120s

# 7. Summary
echo ""
echo "==> Deployment complete!"
echo ""
kubectl get all -n "${NAMESPACE}"
echo ""
echo "Access via NodePort: http://localhost:30080"
echo "Access via Ingress:  http://muchtodo.local (add '127.0.0.1 muchtodo.local' to /etc/hosts)"
echo "Health check:        http://localhost:30080/health"
