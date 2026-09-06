
# resource "aws_route53_zone" "main" {
#   name = var.domain_name
#   tags = var.tags
# }

data "aws_route53_zone" "main" {
  name = var.domain_name
}

locals {
  app_fqdn = "${var.app_subdomain}.${var.domain_name}" # e.g. pulse.suworks.me
}

# use this if  you want route 53 to route traffic to your alb

resource "aws_route53_record" "alb_alias" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.app_fqdn
  type    = "A"

  alias {
    name                   = module.alb.dns_name
    zone_id                = module.alb.zone_id
    evaluate_target_health = true
  }
}


# output "name_servers" {
#   description = "The Name Servers to update at your registrar"
#   value       = aws_route53_zone.main.name_servers
# }

