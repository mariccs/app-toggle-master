output "evaluation_service_role_arn" {
  value = aws_iam_role.evaluation_service_irsa.arn
}

output "analytics_service_role_arn" {
  value = aws_iam_role.analytics_service_irsa.arn
}
