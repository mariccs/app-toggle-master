data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

data "aws_iam_policy_document" "github_actions_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_org_repo}:*",
        "repo:${split("/", var.github_org_repo)[0]}@*/${split("/", var.github_org_repo)[1]}@*:*",
      ]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.project_name}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume.json
}

data "aws_iam_policy_document" "github_actions_permissions" {
  statement {
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = var.ecr_repository_arns
  }
}

resource "aws_iam_role_policy" "github_actions_permissions" {
  name   = "ecr-push"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_permissions.json
}

# --- Self-healing (Fase 4) ---
# A workflow de self-healing (.github/workflows/self-heal.yml) assume este
# mesmo role para rodar "aws eks update-kubeconfig" e, em seguida,
# "kubectl rollout restart". DescribeCluster é o que update-kubeconfig
# precisa; a permissão de fato dentro do cluster vem do Access Entry
# abaixo (RBAC nativo do IAM no EKS, sem precisar editar o ConfigMap
# aws-auth à mão).
data "aws_iam_policy_document" "github_actions_eks_describe" {
  statement {
    effect    = "Allow"
    actions   = ["eks:DescribeCluster"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_actions_eks_describe" {
  name   = "eks-describe-cluster"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_eks_describe.json
}

resource "aws_eks_access_entry" "github_actions_self_heal" {
  cluster_name  = var.eks_cluster_name
  principal_arn = aws_iam_role.github_actions.arn
}

resource "aws_eks_access_policy_association" "github_actions_self_heal" {
  cluster_name  = var.eks_cluster_name
  principal_arn = aws_iam_role.github_actions.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = ["togglemaster"]
  }
}
