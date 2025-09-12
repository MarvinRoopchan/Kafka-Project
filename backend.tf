terraform {

  backend "s3" {

    bucket = "marvin-demo-bucket-12345"

    key = "project/terraform.tfstate"

    region = "us-east-1"

    dynamodb_table = "iac-terraform-backend"

    encrypt = true

  }

}
