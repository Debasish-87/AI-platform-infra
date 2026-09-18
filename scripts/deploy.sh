#!/usr/bin/env bash
# Deploy the sample app to the cluster using the raw manifests in
# kubernetes/base/ (no Helm, no ArgoCD - direct kubectl apply).
#
# Usage:
#   IMAGE_URI=<account>.dkr.ecr.<region>.amazonaws.com/sample-app:latest scripts/deploy.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -z "${IMAGE_URI:-}" ]; then
  echo "ERROR: IMAGE_URI is not set." >&2
  echo "Usage: IMAGE_URI=<account>.dkr.ecr.<region>.amazonaws.com/sample-app:latest $0" >&2
  exit 1
fi

echo "Deploying sample-app with image: ${IMAGE_URI}"

kubectl apply -f "${ROOT_DIR}/kubernetes/base/namespace.yaml"
envsubst < "${ROOT_DIR}/kubernetes/base/deployment.yaml" | kubectl apply -f -
kubectl apply -f "${ROOT_DIR}/kubernetes/base/service.yaml"

kubectl rollout status deployment/sample-app -n sample-app --timeout=180s

echo
echo "Deployment successful."
kubectl get service sample-app -n sample-app
