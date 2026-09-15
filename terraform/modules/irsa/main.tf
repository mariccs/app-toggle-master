data "aws_iam_policy_document" "evaluation_service_irsa_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.namespace}:evaluation-service-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "evaluation_service_irsa" {
  name               = "${var.project_name}-evaluation-service-irsa"
  assume_role_policy = data.aws_iam_policy_document.evaluation_service_irsa_assume.json
}

data "aws_iam_policy_document" "evaluation_service_sqs_send" {
  statement {
    effect    = "Allow"
    actions   = ["sqs:SendMessage", "sqs:GetQueueAttributes", "sqs:GetQueueUrl"]
    resources = [var.sqs_queue_arn]
  }
}

resource "aws_iam_role_policy" "evaluation_service_sqs_send" {
  name   = "sqs-send"
  role   = aws_iam_role.evaluation_service_irsa.id
  policy = data.aws_iam_policy_document.evaluation_service_sqs_send.json
}

data "aws_iam_policy_document" "analytics_service_irsa_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.namespace}:analytics-service-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "analytics_service_irsa" {
  name               = "${var.project_name}-analytics-service-irsa"
  assume_role_policy = data.aws_iam_policy_document.analytics_service_irsa_assume.json
}

data "aws_iam_policy_document" "analytics_service_permissions" {
  statement {
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
    ]
    resources = [var.sqs_queue_arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:Query"]
    resources = [var.dynamodb_table_arn]
  }
}

resource "aws_iam_role_policy" "analytics_service_permissions" {
  name   = "sqs-dynamodb"
  role   = aws_iam_role.analytics_service_irsa.id
  policy = data.aws_iam_policy_document.analytics_service_permissions.json
}
