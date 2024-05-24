data "aws_lb" "api" {
  tags = {
    "ingress.k8s.aws/stack" = "${var.company}/flaskapp-${var.company}"
  }
}

data "aws_lb_listener" "api" {
  load_balancer_arn = data.aws_lb.api.arn
  port              = 80
}

locals {
  api_gateway_name = "${var.company}_${var.environment}"
}

module "api_gateway" {
  source  = "terraform-aws-modules/apigateway-v2/aws"
  version = "~> 5.0.0"

  name          = local.api_gateway_name
  description   = "API Gateway for ${var.environment} environment"
  protocol_type = "HTTP"

  authorizers = {
    lambda = {
      authorizer_payload_format_version = "2.0"
      authorizer_type                   = "REQUEST"
      authorizer_uri                    = module.lambda_function_authorizor.lambda_function_invoke_arn
      enable_simple_responses           = true
      identity_sources                  = ["$request.header.Authorization"]
      name                              = "lambda_authorizer"
    }
  }

  cors_configuration = {
    allow_headers = ["content-type", "x-amz-date", "authorization", "x-api-key", "x-amz-security-token", "x-amz-user-agent"]
    allow_methods = ["*"]
    allow_origins = ["https://${local.site_domain}"]
  }

  create_certificate    = false
  create_domain_name    = true
  create_domain_records = false

  domain_name                 = local.site_domain
  domain_name_certificate_arn = aws_acm_certificate.this.arn

  disable_execute_api_endpoint = false

  stage_access_log_settings = {
    create_log_group            = true
    log_group_retention_in_days = 3
  }

  stage_default_route_settings = {
    detailed_metrics_enabled = true
    throttling_burst_limit   = 50
    throttling_rate_limit    = 50
  }

  routes = {
    "POST /generate" = {
      authorization_type = "CUSTOM"
      authorizer_key     = "lambda"
      integration = {
        connection_type = "VPC_LINK"
        method          = "ANY"
        type            = "HTTP_PROXY"
        uri             = data.aws_lb_listener.api.arn
        vpc_link_key    = "vpc"
      }
    }
    "$default" = {
      authorization_type = "CUSTOM"
      authorizer_key     = "lambda"
      integration = {
        connection_type = "VPC_LINK"
        method          = "ANY"
        type            = "HTTP_PROXY"
        uri             = data.aws_lb_listener.api.arn
        vpc_link_key    = "vpc"
      }
    }
  }

  vpc_links = {
    vpc = {
      name               = local.api_gateway_name
      security_group_ids = [aws_security_group.apigw_vpc_link.id]
      subnet_ids         = concat(module.vpc.private_subnets)
    }
  }

  tags = local.tags
}

resource "aws_security_group" "apigw_vpc_link" {
  name        = "${local.api_gateway_name}_sg"
  vpc_id      = module.vpc.vpc_id
  description = "${local.api_gateway_name} security group"
  tags        = merge(local.tags, { Name = "${local.api_gateway_name}_sg" })
}

resource "aws_security_group_rule" "api_gw_vpc_link_egress" {
  type        = "egress"
  protocol    = -1
  from_port   = 0
  to_port     = 0
  cidr_blocks = [module.vpc.vpc_cidr_block]

  security_group_id = aws_security_group.apigw_vpc_link.id
}

resource "aws_security_group_rule" "api_gw_vpc_link_ingress" {
  type        = "ingress"
  protocol    = -1
  from_port   = 0
  to_port     = 0
  cidr_blocks = [module.vpc.vpc_cidr_block]

  security_group_id = aws_security_group.apigw_vpc_link.id
}
