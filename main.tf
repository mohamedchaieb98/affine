
terraform {
  required_version = ">= 1.3.0"

  backend "s3" {
    bucket  = "backend-tfstates-tf"
    key     = "affine/terraform.tfstate"
    region  = "eu-west-3"
  }
}

provider "aws" {
  region  = "eu-west-3"
  profile = "default"
}
