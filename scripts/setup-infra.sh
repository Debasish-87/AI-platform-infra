#!/usr/bin/env bash
# Central, single entry point for the full manual infra setup:
#   1. Bootstrap the Terraform remote state backend (S3 + DynamoDB) - only
#      needs to run once ever, safe to re-run (idempotent).
#   2. Apply the dev environment (VPC, IAM, ECR, EKS, GitHub OIDC role).
#   3. Point kubectl at the new cluster.
#
# Usage:
#   scripts/setup-infra.sh your-github-org/your-repo-name
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AWS_REGION="${AWS_REGION:-ap-south-1}"
GITHUB_REPO="${1:-${GITHUB_REPO:-}}"

if [ -z "${GITHUB_REPO}" ]; then
  echo "ERROR: GitHub repo not provided." >&2
  echo "Usage: $0 your-github-org/your-repo-name" >&2
  exit 1
fi

echo "================================================================"
echo " AI Platform Infra - full setup"
echo "================================================================"
echo " AWS account : $(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo 'UNKNOWN - check AWS credentials')"
echo " Region      : ${AWS_REGION}"
echo " GitHub repo : ${GITHUB_REPO}"
echo "================================================================"
read -r -p "Type 'yes' to continue: " CONFIRM
[ "${CONFIRM}" = "yes" ] || { echo "Aborted."; exit 1; }

echo
echo "== [1/3] Terraform state backend (S3 + DynamoDB) =="
(cd "${ROOT_DIR}/terraform/bootstrap" && \
  terraform init -input=false && \
  terraform apply -auto-approve \
    -var="terraform_state_bucket=ai-platform-infra-terraform-state" \
    -var="terraform_lock_table=ai-platform-infra-terraform-lock")

echo
echo "== [2/3] Dev environment (VPC, IAM, ECR, EKS, GitHub OIDC) =="
(cd "${ROOT_DIR}/terraform/environments/dev" && \
  terraform init -input=false && \
  terraform apply -auto-approve -var="github_repo=${GITHUB_REPO}")

echo
echo "== [3/3] Configuring kubectl =="
(cd "${ROOT_DIR}/terraform/environments/dev" && \
  aws eks update-kubeconfig --region "${AWS_REGION}" --name "$(terraform output -raw cluster_name)")

kubectl get nodes -o wide

echo
echo "================================================================"
echo " Infra setup complete."
echo "================================================================"
ROLE_ARN=$(cd "${ROOT_DIR}/terraform/environments/dev" && terraform output -raw github_actions_role_arn)
echo
echo "Next steps:"
echo "  1. Add this as the GitHub secret AWS_DEPLOY_ROLE_ARN:"
echo "       ${ROLE_ARN}"
echo "  2. Create a 'production' GitHub Environment with a required reviewer."
echo "  3. scripts/verify-infra.sh"
echo "  4. scripts/deploy.sh   (or push to main and let CI/CD do it)"
