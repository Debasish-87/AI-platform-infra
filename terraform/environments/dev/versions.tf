terraform {

  required_version = ">=1.8.0"

  required_providers {

    aws = {

      source = "hashicorp/aws"

      version = "~>5.0"

    }

  }

}

terraform {
  backend "s3" {
    bucket         = "ai-platform-infra-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "ai-platform-infra-terraform-lock"
    encrypt        = true
  }
}
