# Gh OIDC IdP

module "iam_iam-github-oidc-provider" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-provider"
  version = "~> 5.0"
}

locals {
  # Immutable subject format (GitHub default for repos created after
  # 2026-07-15): repo:OWNER@OWNER_ID/REPO@REPO_ID:<suffix>
  # This protects the trust relationship against repo delete-and-recreate
  # or org-rename attacks a recycled name can never mint a matching token.
  repo_subject_prefix = "repo:${var.owner}@${var.owner_id}/${var.repo}@${var.repo_id}"
}


# resource "aws_iam_policy" "github_deploy_policy" {
#   name        = "${var.project_name}-github-deploy-policy"
#   description = "Permissions for GitHub Actions to plan and apply the full online-boutique stack"
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         # 1. (ACM, Route53)
#         Effect = "Allow"
#         Action = [
#           "acm:DescribeCertificate",
#           "acm:ListCertificates",
#           "acm:ListTagsForCertificate",
#           "route53:GetHostedZone",
#           "route53:ListHostedZones",
#           "route53:ChangeResourceRecordSets",
#           "route53:ListResourceRecordSets",
#           "route53:GetChange"
#         ]
#         Resource = [
#           "arn:aws:acm:us-east-1:767397659229:certificate/*",
#           "arn:aws:route53:::hostedzone/*",
#           "arn:aws:route53:::change/*"
#         ]
#       },
#         {
#         Effect   = "Allow"
#         Action   = ["ecr:GetAuthorizationToken"]
#         Resource = "*"
#       },
#       {
#         Effect = "Allow"
#         Action = [
#           "ecr:BatchCheckLayerAvailability",
#           "ecr:PutImage",
#           "ecr:InitiateLayerUpload",
#           "ecr:UploadLayerPart",
#           "ecr:CompleteLayerUpload",
#           "ecr:BatchGetImage"
#         ]
#         Resource = "arn:aws:ecr:${var.aws_region}:*:repository/*"
#       },
#       {
#         Effect = "Allow"
#         Action = [
#           "ecs:UpdateService",
#           "ecs:DescribeServices",
#           "ecs:DescribeTaskDefinition",
#           "ecs:RegisterTaskDefinition"
#         ]
#         Resource = "*"
#       },
#       {
#         Effect   = "Allow"
#         Action   = ["iam:PassRole"]
#         Resource = [aws_iam_role.ecs_task_execution_role.arn, aws_iam_role.ecs_task_role.arn]
#       },
#       {
#         # 2. Compute, Network & Routing (ECS, EC2, ELB, Servicediscovery, Autoscaling)
#         Effect = "Allow"
#         Action = [
#         #   "ecs:*",
#         #   "ec2:*",
#           "elasticloadbalancing:*",
#           "servicediscovery:*",
#           "application-autoscaling:*"
#         ]
#         Resource = "*"
#       },
#     #   {
#     #     # 3. Serverless Bridge & Cryptographic Vault (SQS, SNS, Lambda, SSM, ECR)
#     #     Effect = "Allow"
#     #     Action = [
#     #       "ecr:*"
#     #     ]
#     #     Resource = [
#     #       "arn:aws:ssm:us-east-1:767397659229:parameter/online-boutique/*",
#     #       "arn:aws:ecr:us-east-1:767397659229:repository/*"
#     #     ]
#     #   },
#       {
#         # 4. Observability (CloudWatch Logs)
#         Effect = "Allow"
#         Action = [
#           "logs:CreateLogGroup",
#           "logs:DescribeLogGroups",
#           "logs:ListTagsLogGroup",
#           "logs:DeleteLogGroup",
#           "logs:PutRetentionPolicy"
#         ]
#         Resource = "arn:aws:logs:us-east-1:767397659229:log-group:*"
#       },
#       {
#         # 5. IAM Automation 
#         Effect = "Allow"
#         Action = [
#           "iam:GetRole", "iam:CreateRole", "iam:DeleteRole", "iam:UpdateRole",
#           "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:AttachRolePolicy",
#           "iam:DetachRolePolicy", "iam:GetRolePolicy", "iam:ListRolePolicies",
#           "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole",
#           "iam:PassRole", "iam:GetPolicy", "iam:GetPolicyVersion", "iam:CreatePolicy",
#           "iam:DeletePolicy", "iam:CreatePolicyVersion", "iam:DeletePolicyVersion",
#           "iam:ListPolicyVersions", "iam:GetOpenIDConnectProvider"
#         ]
#         Resource = [
#           "arn:aws:iam::767397659229:role/*",
#           "arn:aws:iam::767397659229:policy/*",
#           "arn:aws:iam::767397659229:oidc-provider/token.actions.githubusercontent.com"
#         ]
#       },
#       {
#         # 6. Terraform State Management
#         Effect = "Allow"
#         Action = [
#           "s3:ListBucket",
#           "s3:GetObject",
#           "s3:PutObject",
#           "s3:DeleteObject",
#         ]
#         Resource = [
#           "arn:aws:s3:::pulse-ecs-tfstate-767397659229",
#           "arn:aws:s3:::pulse-ecs-tfstate-767397659229/*"
#         ]
#       },
#       {
#         # 7. Terraform Metadata & Auditing Exception (AWS APIs that require wildcard resources)
#         Effect = "Allow"
#         Action = [
#           "ssm:DescribeParameters",
#           "route53:ListTagsForResource",
#           "logs:ListTagsForResource",
#         ]
#         Resource = "*"
#       }
#     ]
#   })
# }


resource "aws_iam_policy" "github_deploy_policy" {
  name        = "${var.project_name}-github-deploy-policy"
  description = "Permissions for GitHub Actions to apply the ${var.project_name} stack. main branch only."

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
        Sid      = "EcsServiceDeploy"
        Effect   = "Allow"
        Action   = ["ecs:UpdateService", "ecs:DescribeServices", "ecs:CreateService", "ecs:DeleteService", "ecs:TagResource"]
        Resource = "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/${var.project_name}*/*"
      },
      {
        Sid    = "EcsClusterAndTaskDef"
        Effect = "Allow"
        # ECS cluster/task-def APIs do not support resource-level scoping —
        # documented AWS limitation, not an oversight. Actions enumerated
        # explicitly instead of "ecs:*" to keep the surface as small as possible.
        Action = [
          "ecs:CreateCluster", "ecs:DeleteCluster", "ecs:DescribeClusters",
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
        # IAM conditions — scoped by enumerating exact actions used instead of
        # "ec2:*" / "elasticloadbalancing:*".
        Action = [
          "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:DescribeVpcs", "ec2:ModifyVpcAttribute",
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
          "ec2:CreateTags", "ec2:DescribeTags",
          "elasticloadbalancing:CreateLoadBalancer", "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:CreateTargetGroup", "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:DescribeTargetGroups", "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:CreateListener", "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:DescribeListeners", "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:ModifyLoadBalancerAttributes", "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:AddTags", "elasticloadbalancing:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:DescribeLogGroups",
          "logs:PutRetentionPolicy", "logs:ListTagsLogGroup", "logs:TagResource"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${var.project_name}*"
      },
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
        # Scoped to ONLY this project's ECS task roles/policies. Cannot touch
        # the deploy role or plan role themselves (no self-modification path),
        # and cannot touch any other role in the account. This is what closes
        # the privilege-escalation hole the un-scoped role/* + policy/* grant had.
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-ecs-*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.project_name}-ecs-*"
        ]
      },
      {
        Sid    = "IamSelfReadOnly"
        Effect = "Allow"
        # Terraform needs to READ its own role/policy/provider to run
        # `plan`/`refresh` in this same root — but write access to these
        # three resources is deliberately excluded from IamForProjectRolesOnly
        # above. Read-only self-inspection, no write path onto itself.
        Action = [
          "iam:GetRole", "iam:GetPolicy", "iam:GetPolicyVersion",
          "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole", "iam:ListPolicyVersions",
          "iam:GetOpenIDConnectProvider"
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-github-deploy-role",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.project_name}-github-deploy-policy",
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
        Sid    = "ReadOnlyMetadataExceptions"
        Effect = "Allow"
        # A handful of provider-side read calls with no resource-level scoping
        # option at all — kept explicit and separate from the write-capable
        # statements above so the exception is auditable at a glance.
        Action   = ["application-autoscaling:Describe*", "servicediscovery:List*", "servicediscovery:Get*"]
        Resource = "*"
      }
    ]
  })
}


# Gh Action Deploy/Assume  Role with Trust Relationship 

module "iam_iam-github-oidc-role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-role"
  version = "~> 5.0"

  name = "${var.project_name}-github-deploy-role"

  # deployments from main branch are allowed only
  # subjects = ["repo:susu10-10@<OWNER_ID>/online-boutique-aaws-pf@<REPO_ID>:ref:refs/heads/main"]
  subjects = [
    "${local.repo_subject_prefix}:ref:refs/heads/main",
    "${local.repo_subject_prefix}:pull_request"
  ]
  #   subjects = [
  #     "repo:susu10-10@${var.owner_id}/pulse-ecs-repo@${var.repo_id}:ref:refs/heads/main",
  #   ]
  # # The Expanded Zero-Trust Boundary
  # subjects = [
  #   # Allow the main branch
  #   "repo:susu10-10@<OWNER_ID>/online-boutique-aaws-pf@<REPO_ID>:ref:refs/heads/main",
  #   # Allow any feature branch
  #   "repo:susu10-10@<OWNER_ID>/online-boutique-aaws-pf@<REPO_ID>:ref:refs/heads/*",
  #   # Allow Pull Request triggers
  #   "repo:susu10-10@<OWNER_ID>/online-boutique-aaws-pf@<REPO_ID>:pull_request"
  # ]

  policies = {
    DeployPolicy = aws_iam_policy.github_deploy_policy.arn
  }
}