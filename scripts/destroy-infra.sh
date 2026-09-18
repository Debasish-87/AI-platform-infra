#!/usr/bin/env bash
# Central, single entry point to FULLY tear down all infra created by
# setup-infra.sh. Irreversible - asks for confirmation.
#
# Order: app resources -> monitoring -> dev environment (EKS/ECR/IAM/VPC/
# GitHub OIDC) -> (state backend is left alone by default, see below).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "================================================================"
echo " AI Platform Infra - FULL teardown"
echo "================================================================"
echo " AWS account : $(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo 'UNKNOWN - check AWS credentials')"
echo "================================================================"
echo "This is IRREVERSIBLE. It destroys the EKS cluster, VPC, ECR repo"
echo "(and any images in it), IAM roles, and the GitHub OIDC role."
echo
read -r -p "Type 'yes' to continue: " CONFIRM
[ "${CONFIRM}" = "yes" ] || { echo "Aborted."; exit 1; }

echo
echo "== Removing app + monitoring resources (avoids an orphaned Load"
echo "   Balancer / security group blocking VPC deletion) =="
if kubectl cluster-info >/dev/null 2>&1; then
  kubectl delete -f "${ROOT_DIR}/kubernetes/base/" --ignore-not-found
  helm uninstall grafana -n monitoring >/dev/null 2>&1 || true
  helm uninstall prometheus -n monitoring >/dev/null 2>&1 || true
  kubectl delete namespace monitoring --ignore-not-found
else
  echo "kubectl not connected - skipping (nothing to clean up, or cluster already gone)"
fi

echo
echo "== Destroying dev environment (EKS, ECR, IAM, VPC, GitHub OIDC) =="
(cd "${ROOT_DIR}/terraform/environments/dev" && terraform destroy -auto-approve)

echo
echo "================================================================"
echo " Dev environment destroyed."
echo "================================================================"
echo "The Terraform state backend (S3 bucket + DynamoDB lock table) was"
echo "deliberately left alone - destroying it deletes your state history."
echo "If you really want it gone too:"
echo "  cd terraform/bootstrap && terraform destroy"
