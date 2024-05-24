data "aws_route53_zone" "public" {
  name = var.domain

  private_zone = false
}

resource "aws_route53_record" "site" {
  zone_id = data.aws_route53_zone.public.zone_id
  name    = local.site_domain
  type    = "A"

  alias {
    name                   = module.cdn.cloudfront_distribution_domain_name
    zone_id                = module.cdn.cloudfront_distribution_hosted_zone_id
    evaluate_target_health = true
  }
}
