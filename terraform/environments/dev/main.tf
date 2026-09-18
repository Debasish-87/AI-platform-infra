module "vpc" {
  source = "../../modules/vpc"

  project_name = var.project_name
  environment  = var.environment

  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones

  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
}

module "iam" {
  source = "../../modules/iam"

  cluster_name = "${var.project_name}-${var.environment}"
}

module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = var.environment

  repository_name = "sample-app"
}

module "eks" {
  source = "../../modules/eks"

  project_name = var.project_name
  environment  = var.environment

  cluster_name    = "${var.project_name}-${var.environment}"
  cluster_version = "1.32"

  subnet_ids = module.vpc.private_subnet_ids

  cluster_role_arn    = module.iam.cluster_role_arn
  node_group_role_arn = module.iam.node_group_role_arn
}

module "github_oidc" {
  source = "../../modules/github-oidc"

  github_repo         = var.github_repo
  cluster_name        = module.eks.cluster_name
  ecr_repository_arn  = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${module.ecr.repository_name}"
  create_oidc_provider = var.create_oidc_provider

  depends_on = [module.eks]
}

data "aws_caller_identity" "current" {}
