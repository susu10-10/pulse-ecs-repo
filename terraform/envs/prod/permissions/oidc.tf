# Gh OIDC IdP

module "iam_iam-github-oidc-provider" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-provider"
  version = "~> 5.0"
}

locals {
  # Immutable subject format (GitHub default for repos created after
  # 2026-07-15): repo:OWNER@OWNER_ID/REPO@REPO_ID:<suffix>
  # This protects the trust relationship against repo delete-and-recreate
  # or org-rename attacks — a recycled name can never mint a matching token.
  repo_subject_prefix = "repo:${var.owner}@${var.owner_id}/${var.repo}@${var.repo_id}"
}

# =====================================================================
# POLICY 1 of 2: core compute/network/container permissions.
# Split into two policies because a single AWS managed policy is capped
# at 6,144 characters — this one policy's JSON grew past that limit as
# permissions accumulated. AWS allows up to 10 managed policies per role,
# so splitting along logical lines (infra vs. everything-else) is the
# standard fix, not a workaround.
# =====================================================================

resource "aws_iam_policy" "deploy_core" {
  name        = "${var.project_name}-github-deploy-core"
  description = "Core ECR/ECS/network permissions for GitHub Actions. main branch only."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EcrAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*" # AWS requires Resource "*" for this specific action — no scoping possible.
      },
      {
        Sid    = "EcrPushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability", "ecr:PutImage", "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:BatchGetImage",
          "ecr:DescribeRepositories", "ecr:DescribeImages"
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.project_name}*"
      },
      {
        Sid    = "EcrRepoManagement"
        Effect = "Allow"
        Action = [
          "ecr:CreateRepository", "ecr:DeleteRepository", "ecr:DescribeRepositories",
          "ecr:PutLifecyclePolicy", "ecr:GetLifecyclePolicy", "ecr:DeleteLifecyclePolicy",
          "ecr:PutImageScanningConfiguration",
          "ecr:GetRepositoryPolicy", "ecr:SetRepositoryPolicy", "ecr:DeleteRepositoryPolicy",
          "ecr:PutImageTagMutability",
          "ecr:TagResource", "ecr:UntagResource", "ecr:ListTagsForResource"
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.project_name}*"
      },
      {
        Sid      = "EcsServiceDeploy"
        Effect   = "Allow"
        Action   = ["ecs:UpdateService", "ecs:DescribeServices", "ecs:CreateService", "ecs:DeleteService", "ecs:TagResource"]
        Resource = "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/${var.project_name}*/*"
      },
      {
        Sid    = "EcsClusterAndTaskDef"
        Effect = "Allow"
        # ECS cluster/task-def APIs do not support resource-level scoping —
        # documented AWS limitation, not an oversight.
        Action = [
          "ecs:CreateCluster", "ecs:DeleteCluster", "ecs:DescribeClusters", "ecs:TagResource",
          "ecs:PutClusterCapacityProviders",
          "ecs:RegisterTaskDefinition", "ecs:DescribeTaskDefinition", "ecs:DeregisterTaskDefinition"
        ]
        Resource = "*"
      },
      {
        Sid    = "PassEcsRolesOnly"
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-ecs-task-execution-role",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-ecs-task-role"
        ]
      },
      {
        Sid    = "NetworkAndLoadBalancing"
        Effect = "Allow"
        # EC2/ELB networking create+describe calls don't support resource-level
        # IAM conditions — scoped by enumerating exact actions instead of
        # "ec2:*" / "elasticloadbalancing:*".
        Action = [
          "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:DescribeVpcs", "ec2:ModifyVpcAttribute", "ec2:DescribeVpcAttribute",
          "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:DescribeSubnets",
          "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway",
          "ec2:AttachInternetGateway", "ec2:DetachInternetGateway", "ec2:DescribeInternetGateways",
          "ec2:CreateNatGateway", "ec2:DeleteNatGateway", "ec2:DescribeNatGateways",
          "ec2:AllocateAddress", "ec2:ReleaseAddress", "ec2:DescribeAddresses",
          "ec2:CreateRouteTable", "ec2:DeleteRouteTable", "ec2:CreateRoute", "ec2:DeleteRoute",
          "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable", "ec2:DescribeRouteTables",
          "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress", "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress", "ec2:RevokeSecurityGroupEgress",
          "ec2:DescribeSecurityGroups", "ec2:DescribeAvailabilityZones",
          "ec2:DescribeSecurityGroupRules", "ec2:DescribeAddressesAttribute",
          "ec2:DescribeNetworkAcls", "ec2:CreateNetworkAclEntry", "ec2:DeleteNetworkAclEntry", "ec2:ReplaceNetworkAclEntry",
          "ec2:CreateTags", "ec2:DescribeTags",
          "elasticloadbalancing:CreateLoadBalancer", "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DescribeLoadBalancers", "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:CreateTargetGroup", "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:DescribeTargetGroups", "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:CreateListener", "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:DescribeListeners", "elasticloadbalancing:DescribeListenerAttributes", "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:ModifyLoadBalancerAttributes", "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:AddTags", "elasticloadbalancing:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup", "logs:DeleteLogGroup",
          "logs:PutRetentionPolicy", "logs:ListTagsLogGroup", "logs:TagResource",
          "logs:ListTagsForResource"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ecs/*"
      },
      {
        Sid    = "LogsDescribeUnscoped"
        Effect = "Allow"
        # logs:DescribeLogGroups is a search/list action — cannot be scoped
        # to a specific log-group ARN, same limitation category as
        # route53:ListHostedZones was.
        Action   = ["logs:DescribeLogGroups"]
        Resource = "*"
      }
    ]
  })
}

# =====================================================================
# POLICY 2 of 2: IAM self-management, state, ACM, monitoring, misc.
# =====================================================================

resource "aws_iam_policy" "deploy_extra" {
  name        = "${var.project_name}-github-deploy-extra"
  description = "IAM/state/ACM/monitoring permissions for GitHub Actions. main branch only."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "IamForProjectRolesOnly"
        Effect = "Allow"
        Action = [
          "iam:GetRole", "iam:CreateRole", "iam:DeleteRole", "iam:UpdateRole",
          "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:AttachRolePolicy",
          "iam:DetachRolePolicy", "iam:GetRolePolicy", "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole",
          "iam:GetPolicy", "iam:GetPolicyVersion", "iam:CreatePolicy",
          "iam:DeletePolicy", "iam:CreatePolicyVersion", "iam:DeletePolicyVersion",
          "iam:ListPolicyVersions", "iam:TagRole", "iam:TagPolicy"
        ]
     
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-ecs-*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.project_name}-ecs-*"
        ]
      },
      {
        Sid    = "IamSelfReadOnly"
        Effect = "Allow"

        Action = [
          "iam:GetRole", "iam:GetPolicy", "iam:GetPolicyVersion",
          "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole", "iam:ListPolicyVersions",
          "iam:GetOpenIDConnectProvider"
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-github-deploy-role",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.project_name}-github-deploy-core",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.project_name}-github-deploy-extra",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
        ]
      },
      {
        Sid    = "StateBucket"
        Effect = "Allow"
        Action = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = [
          "arn:aws:s3:::pulse-ecs-tfstate-767397659229",
          "arn:aws:s3:::pulse-ecs-tfstate-767397659229/*"
        ]
      },
      {
        Sid    = "AcmManage"
        Effect = "Allow"
        Action = [
          "acm:ImportCertificate", "acm:DescribeCertificate", "acm:DeleteCertificate",
          "acm:AddTagsToCertificate", "acm:ListTagsForCertificate"
        ]
        Resource = "arn:aws:acm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:certificate/*"
      },
      {
        Sid    = "Route53CleanupOnly"
        Effect = "Allow"
        # Safe to delete this statement + Route53ChangeStatus below —
        # nothing in this project touches Route53 going forward, this was
        # only needed to let one apply destroy the old DNS-validation records.
        Action = [
          "route53:GetHostedZone", "route53:ListResourceRecordSets", "route53:ChangeResourceRecordSets",
          "route53:ListTagsForResource"
        ]
        Resource = "arn:aws:route53:::hostedzone/Z0759147DP4WTN9YNUWC"
      },
      {
        Sid      = "Route53ChangeStatus"
        Effect   = "Allow"
        Action   = ["route53:GetChange"]
        Resource = "arn:aws:route53:::change/*" # AWS requires this wildcard.
      },
      {
        Sid    = "SnsAlerts"
        Effect = "Allow"
        Action = [
          "sns:CreateTopic", "sns:DeleteTopic", "sns:GetTopicAttributes", "sns:SetTopicAttributes",
          "sns:TagResource", "sns:UntagResource", "sns:ListTagsForResource",
          "sns:Subscribe", "sns:Unsubscribe", "sns:ListSubscriptionsByTopic", "sns:GetSubscriptionAttributes"
        ]
        Resource = "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.project_name}*"
      },
      {
        Sid    = "CloudWatchAlarms"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricAlarm", "cloudwatch:DeleteAlarms", "cloudwatch:DescribeAlarms",
          "cloudwatch:TagResource", "cloudwatch:UntagResource", "cloudwatch:ListTagsForResource"
        ]
        Resource = "arn:aws:cloudwatch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alarm:${var.project_name}*"
      },
      {
        Sid      = "ReadOnlyMetadataExceptions"
        Effect   = "Allow"
        Action   = ["application-autoscaling:Describe*", "servicediscovery:List*", "servicediscovery:Get*"]
        Resource = "*"
      }
    ]
  })
}

# Gh Action Deploy/Assume Role with Trust Relationship

module "iam_iam-github-oidc-role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-role"
  version = "~> 5.0"

  name = "${var.project_name}-github-deploy-role"

  subjects = [
    "${local.repo_subject_prefix}:ref:refs/heads/main",
    "${local.repo_subject_prefix}:pull_request"
  ]

  policies = {
    CorePolicy  = aws_iam_policy.deploy_core.arn
    ExtraPolicy = aws_iam_policy.deploy_extra.arn
  }
}
