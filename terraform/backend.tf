terraform {
  backend "s3" {
    bucket = "bsc.sandbox.terraform.state"
    key    = "dreamcanvas/terraform.tfstate"
    region = "us-east-2"
  }
}
