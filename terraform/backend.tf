terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "jaydemy-tfstate-458108203924"   
    key            = "kubernetes-experiments.tfstate"
    region         = "ap-south-1"
    encrypt        = true
  }
}
