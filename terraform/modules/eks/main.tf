resource "aws_eks_cluster" "this" {

  name     = var.cluster_name
  role_arn = var.cluster_role_arn

  version = var.cluster_version

  vpc_config {

    subnet_ids = var.subnet_ids

    endpoint_public_access  = true
    endpoint_private_access = true
  }

  # API_AND_CONFIG_MAP: lets the github-oidc module grant the CI/CD role
  # scoped kubectl access via an EKS access entry, without cluster-admin.
  access_config {
    authentication_mode                          = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions   = true
  }

  tags = {
    Name        = var.cluster_name
    Project     = var.project_name
    Environment = var.environment
  }

}

resource "aws_eks_node_group" "this" {

  cluster_name = aws_eks_cluster.this.name

  node_group_name = "${var.cluster_name}-nodes"

  node_role_arn = var.node_group_role_arn

  subnet_ids = var.subnet_ids

  instance_types = [
    var.node_instance_type
  ]

  scaling_config {

    desired_size = var.desired_size

    min_size = var.min_size

    max_size = var.max_size
  }

  tags = {
    Name        = "${var.cluster_name}-nodes"
    Project     = var.project_name
    Environment = var.environment
  }
}
