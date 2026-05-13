output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = module.ecr.repository_url  
  #value       = terraform.workspace == "prod" ? module.ecr[0].repository_url : "Dev uses prod ECR repo"
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "environment" {
  description = "Current workspace"
  value       = terraform.workspace
}

output "configure_kubectl" {
  description = "Run this after apply to connect kubectl"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
}