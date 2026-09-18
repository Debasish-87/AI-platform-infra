#!/usr/bin/env bash
# Build the sample app image locally (for testing before pushing to ECR).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

docker build \
  -t sample-app:latest \
  -f "${ROOT_DIR}/docker/Dockerfile" \
  "${ROOT_DIR}"

echo
echo "Docker image built: sample-app:latest"
