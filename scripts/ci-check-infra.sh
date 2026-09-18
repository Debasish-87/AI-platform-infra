#!/usr/bin/env bash
# Strict, CI-friendly infra check. Unlike verify-infra.sh (human-readable,
# always exits 0), this exits non-zero on the FIRST hard failure so a
# GitHub Actions job fails fast and the build/deploy jobs never run
# against infra that isn't actually there.
#
# This project's infra is created manually (scripts/setup-infra.sh), never
# by CI - this script only ever READS state, never applies or destroys.
set -uo pipefail

AWS_REGION="${AWS_REGION:-ap-south-1}"
CLUSTER_NAME="${CLUSTER_NAME:-ai-platform-infra-dev}"

fail() { echo "::error::$1"; exit 1; }
ok()   { echo "[OK] $1"; }

echo "== AWS credentials =="
aws sts get-caller-identity --output text >/dev/null || fail "AWS credentials are not valid / not configured"
ok "AWS credentials valid"

echo "== VPC =="
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=ai-platform-infra-dev-vpc" \
  --region "${AWS_REGION}" \
  --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")
[ "${VPC_ID}" != "None" ] && [ -n "${VPC_ID}" ] || fail "VPC not found. Run scripts/setup-infra.sh."
ok "VPC found (${VPC_ID})"

echo "== EKS cluster =="
CLUSTER_STATUS=$(aws eks describe-cluster \
  --name "${CLUSTER_NAME}" \
  --region "${AWS_REGION}" \
  --query 'cluster.status' --output text 2>/dev/null || echo "MISSING")
[ "${CLUSTER_STATUS}" = "ACTIVE" ] || fail "EKS cluster '${CLUSTER_NAME}' is not ACTIVE (status: ${CLUSTER_STATUS}). Run scripts/setup-infra.sh."
ok "EKS cluster ACTIVE"

echo "== ECR repository =="
aws ecr describe-repositories --repository-names sample-app --region "${AWS_REGION}" >/dev/null 2>&1 \
  || fail "ECR repository 'sample-app' not found. Run scripts/setup-infra.sh."
ok "ECR repository found"

echo "== kubectl connectivity =="
aws eks update-kubeconfig --region "${AWS_REGION}" --name "${CLUSTER_NAME}" >/dev/null || fail "Could not update kubeconfig"
kubectl cluster-info >/dev/null 2>&1 || fail "kubectl cannot reach the EKS API. Check the CI role has an EKS access entry (terraform/modules/github-oidc)."
ok "kubectl can reach the cluster API"

echo
echo "All required infra checks passed."
exit 0
