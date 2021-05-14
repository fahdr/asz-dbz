provider "aws" {
  version = "~> 3.39.0"
  region = "us-west-2"
}

provider "random" {
  version = "~> 2.2.1"
}

data "aws_caller_identity" "current" {}