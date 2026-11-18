output "relay_url" {
  description = "URL pública da Lambda Function URL — vai no Secret alertmanager-chatops-secrets, chave SELF_HEAL_RELAY_URL."
  value       = aws_lambda_function_url.self_healing_relay.function_url
}
