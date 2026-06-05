variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  default     = "marvin_user"
}

variable "db_password" {
  description = "RDS master password. Set via TF_VAR_db_password or terraform.tfvars (gitignored)."
  type        = string
  sensitive   = true
}
