module "lambda_function_authorizor" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "${var.company}_${var.environment}_authorizer"
  description   = "${var.company} ${var.environment} function to authorize api gateway"
  handler       = "app.lambda_handler"
  publish       = true
  runtime       = "python3.11"
  timeout       = 30

  create_package = true

  environment_variables = {
    CLUSTER_NAME = module.eks.cluster_name
    NAMESPACE    = var.app_namespace
  }

  source_path = [
    {
      path             = "${path.module}/lambda_authorizer"
      pip_requirements = true
    }
  ]

  attach_policies = true
  policies        = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole", ]

  allowed_triggers = {
    AllowExecutionFromAPIGateway = {
      service    = "apigateway"
      source_arn = "${module.api_gateway.api_execution_arn}/*/*"
    }
  }

  cloudwatch_logs_retention_in_days = 3

  tags = local.tags
}
