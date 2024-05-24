data "aws_ami" "openvpnas" {
  most_recent = true

  filter {
    name = "name"

    values = [
      "OpenVPN Access Server Community Image-fe8020db-5343-4c43-9e65-5ed4a825c931*"
    ]
  }

  owners = [
    "679593333241",
  ]

  include_deprecated = true
}

data "aws_iam_policy_document" "ec2_role" {
  statement {
    effect = "Allow"
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy" "AmazonSSMManagedInstanceCore" {
  name = "AmazonSSMManagedInstanceCore"
}

data "aws_route53_zone" "this" {
  name = var.domain
}

locals {
  openvpn_name = "openvpn"
}

resource "aws_eip" "vpn" {
  tags = merge(var.tags, { Name = "openvpn" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eip_association" "eip_vpn" {
  instance_id   = aws_instance.openvpn.id
  allocation_id = aws_eip.vpn.id
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.company}_ec2_role"
  role = aws_iam_role.ec2_role.name

  tags = var.tags
}

resource "aws_iam_role" "ec2_role" {
  name = "${var.company}_ec2_role"

  assume_role_policy = data.aws_iam_policy_document.ec2_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "AmazonSSMManagedInstanceCore" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = data.aws_iam_policy.AmazonSSMManagedInstanceCore.arn
}

resource "aws_instance" "openvpn" {
  ami = data.aws_ami.openvpnas.id

  disable_api_termination = true
  ebs_optimized           = true
  iam_instance_profile    = aws_iam_instance_profile.this.name
  instance_type           = var.openvpn_instance_type
  key_name                = module.dev.ssh_keypair
  monitoring              = true
  subnet_id               = module.dev.public_subnets[0]
  vpc_security_group_ids  = [aws_security_group.openvpn.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 3
    http_tokens                 = "required"
  }

  tags = merge(var.tags, {
    "Name"        = local.openvpn_name
    "Patch Group" = "A"
    "backup"      = "true"
  })

  volume_tags = merge(var.tags, {
    "Name"   = "${local.openvpn_name}_vol"
    "backup" = "true"
  })

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  lifecycle {
    ignore_changes = [user_data, ami]
  }
}

resource "aws_route53_record" "vpn" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = "vpn-${var.company}.${var.domain}"
  type    = "A"
  ttl     = "300"
  records = [aws_eip.vpn.public_ip]
}

resource "aws_security_group" "openvpn" {
  name        = local.openvpn_name
  vpc_id      = module.dev.vpc_id
  description = "OpenVPN security group"
  tags        = merge(var.tags, { Name = "${local.openvpn_name}-sg" })
}

resource "aws_security_group_rule" "egress_all" {
  type        = "egress"
  protocol    = -1
  from_port   = 0
  to_port     = 0
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.openvpn.id
}

resource "aws_security_group_rule" "ingress_tcp443" {
  type        = "ingress"
  protocol    = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.openvpn.id
}

resource "aws_security_group_rule" "ingress_tcp80" {
  type        = "ingress"
  protocol    = "tcp"
  from_port   = 80
  to_port     = 80
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.openvpn.id
}

resource "aws_security_group_rule" "ingress_udp1194" {
  type        = "ingress"
  protocol    = "udp"
  from_port   = 1194
  to_port     = 1194
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.openvpn.id
}
