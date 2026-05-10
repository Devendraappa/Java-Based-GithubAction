# modules/ecr/outputs.tf
output "repository_url" { value = aws_ecr_repository.bankapp.repository_url }
output "repository_arn" { value = aws_ecr_repository.bankapp.arn }
output "repository_name" { value = aws_ecr_repository.bankapp.name }