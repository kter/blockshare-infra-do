provider "aws" {
  region = "us-east-1"
}

provider "digitalocean" {
  token = var.do_token
}

locals {
  project_name = "blockshare"
  domain = "tomohiko.io"
}

variable "env" {
  default = "stg"
}

variable "db_pass" {
  default = "password"
}

terraform {
  backend "s3" {
    bucket = "terraform.blockshare.tomohiko.io"
    key = "blockshare/terraform.tfstate"
    region = "us-east-1"
  }
}

