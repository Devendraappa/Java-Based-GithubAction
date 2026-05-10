# modules/ecr/variables.tf
variable "project_name" { type = string }
variable "region"       { type = string }
variable "env"          { type = string }   # ← add this