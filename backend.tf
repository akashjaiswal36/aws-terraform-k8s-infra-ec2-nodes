terraform {
  backend "s3" {
    bucket = "k8s-cluster-aws-backend-terraform-s3-bucket"
    key    = "k8s/prod"
    region = "ap-south-1"
  }
}
