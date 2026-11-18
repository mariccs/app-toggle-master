# Self-healing relay (Fase 4): AWS Lambda com Function URL pública,
# chamada pelo Alertmanager (webhook_configs) e que dispara o
# repository_dispatch do GitHub (que por sua vez roda o
# .github/workflows/self-heal.yml e o "kubectl rollout restart").

data "archive_file" "relay" {
  type        = "zip"
  source_file = "${path.module}/relay.py"
  output_path = "${path.module}/.build/relay.zip"
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "self_healing_relay" {
  name               = "${var.project_name}-self-healing-relay"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "basic_logs" {
  role       = aws_iam_role.self_healing_relay.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "self_healing_relay" {
  function_name    = "${var.project_name}-self-healing-relay"
  role             = aws_iam_role.self_healing_relay.arn
  handler          = "relay.handler"
  runtime          = "python3.12"
  timeout          = 10
  filename         = data.archive_file.relay.output_path
  source_code_hash = data.archive_file.relay.output_base64sha256

  environment {
    variables = {
      GITHUB_REPO         = var.github_org_repo
      GITHUB_TOKEN        = var.github_dispatch_token
      RELAY_SHARED_SECRET = var.relay_shared_secret
    }
  }
}

# Function URL pública (sem API Gateway) — mais simples para este
# cenário acadêmico. A autenticação real é o segredo compartilhado
# verificado dentro da própria função (header Authorization: Bearer),
# não o IAM da AWS, porque é o Alertmanager (fora da AWS) quem chama.
resource "aws_lambda_function_url" "self_healing_relay" {
  function_name      = aws_lambda_function.self_healing_relay.function_name
  authorization_type = "NONE"
}
