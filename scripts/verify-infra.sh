#!/usr/bin/env bash
# Human-readable infra health check. Safe to run any time - only reads
# state, never applies or destroys anything.
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AWS_REGION="${AWS_REGION:-ap-south-1}"
CLUSTER_NAME="${CLUSTER_NAME:-ai-platform-infra-dev}"

pass() { echo "  [OK]   $1"; }
fail() { echo "  [FAIL] $1"; }
info() { echo "  [--]   $1"; }

echo "== AWS identity =="
if aws sts get-caller-identity --output table; then pass "AWS credentials valid"; else fail "AWS credentials not configured"; fi

echo
echo "== VPC =="
if aws ec2 describe-vpcs --filters "Name=tag:Name,Values=ai-platform-infra-dev-vpc" --region "${AWS_REGION}" \
    --query 'Vpcs[0].VpcId' --output text 2>/dev/null | grep -q vpc-; then
  pass "VPC exists"
else
  fail "VPC not found - run scripts/setup-infra.sh"
fi

echo
echo "== EKS cluster =="
CLUSTER_STATUS=$(aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" \
  --query 'cluster.status' --output text 2>/dev/null || echo "MISSING")
if [ "${CLUSTER_STATUS}" = "ACTIVE" ]; then
  pass "EKS cluster ACTIVE"
else
  fail "EKS cluster status: ${CLUSTER_STATUS}"
fi

echo
echo "== ECR repository =="
aws ecr describe-repositories --repository-names sample-app --region "${AWS_REGION}" >/dev/null 2>&1 \
  && pass "ECR repository found" || fail "ECR repository not found"

echo
echo "== kubectl connectivity =="
if kubectl cluster-info >/dev/null 2>&1; then
  pass "kubectl connected"
  kubectl get nodes -o wide
else
  fail "kubectl not connected - run: aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}"
fi

echo
echo "== Application =="
kubectl get deployment sample-app -n sample-app 2>/dev/null || info "sample-app not deployed yet"
kubectl get pods -n sample-app -o wide 2>/dev/null
LB_HOST=$(kubectl get service sample-app -n sample-app \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
if [ -n "${LB_HOST}" ]; then
  pass "Load balancer: ${LB_HOST}"
  curl -sf "http://${LB_HOST}/health" && echo && pass "/health reachable" || fail "/health not reachable yet"
else
  info "sample-app service has no external hostname yet"
fi

echo
echo "== Monitoring =="
kubectl get pods -n monitoring 2>/dev/null || info "monitoring not installed (optional: make monitor)"

echo
echo "Done."
