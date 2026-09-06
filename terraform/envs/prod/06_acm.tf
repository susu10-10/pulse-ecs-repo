# module "acm" {
#   source  = "terraform-aws-modules/acm/aws"
#   version = "~> 5.0"

#   domain_name = var.domain_name
#   zone_id     = data.aws_route53_zone.main.zone_id

#   validation_method = "DNS"

#   #   subject_alternative_names = [
#   #     "*.my-domain.com",
#   #     "app.sub.my-domain.com",
#   #   ]

#   wait_for_validation = true

#   tags = var.tags
# }

# Self-signed certificate, imported directly into ACM. No Route53, no
# domain-ownership validation — trades away browser trust for removing the
# cross-project Route53 dependency entirely. Real production deployment
# would use a validated domain + DNS validation instead; call this out in
# the README's production-readiness section.

resource "tls_private_key" "alb" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "alb" {
  private_key_pem = tls_private_key.alb.private_key_pem

  subject {
    common_name  = "${var.project_name}-alb.local"
    organization = "Pulse ECS Assessment"
  }

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "alb" {
  private_key      = tls_private_key.alb.private_key_pem
  certificate_body = tls_self_signed_cert.alb.cert_pem

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}
