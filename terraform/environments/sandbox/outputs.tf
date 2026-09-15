output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_update_kubeconfig_command" {
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

output "vpc_id" {
  value = module.networking.vpc_id
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "rds_endpoints" {
  value = module.database.endpoints
}

output "db_username" {
  value = var.db_username
}

output "db_password" {
  value     = local.db_password
  sensitive = true
}

output "elasticache_endpoint" {
  value = module.cache.endpoint
}

output "dynamodb_table_name" {
  value = module.dynamodb.table_name
}

output "sqs_queue_url" {
  value = module.messaging.queue_url
}

output "sqs_queue_arn" {
  value = module.messaging.queue_arn
}

output "irsa_evaluation_service_role_arn" {
  value = module.irsa.evaluation_service_role_arn
}

output "irsa_analytics_service_role_arn" {
  value = module.irsa.analytics_service_role_arn
}

output "argocd_namespace" {
  value = var.install_argocd ? module.argocd[0].namespace : null
}

output "github_actions_role_arn" {
  value = module.github_oidc.role_arn
}
