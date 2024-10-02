module "dev" {
  source = "./modules/app"

  apps = {
    stablediffusion = {
      description = "Stable diffusion application"
    }
    flaskapp = {
      description = "Flask API"
    }
  }

  app_namespace          = var.company
  company                = var.company
  domain                 = var.domain
  eks_cluster_version    = "1.31"
  eks_node_instance_type = "g4dn.xlarge"
  environment            = "dev"
  openvpn_sg             = aws_security_group.openvpn.id
  site_directory         = "../static-site/build"
  vpc_cidr               = "10.250.0.0/16"
  vpc_redundancy         = false
  web_acl_id             = aws_wafv2_web_acl.this.arn
}