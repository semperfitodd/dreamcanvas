resource "tls_private_key" "default" {
  algorithm = "RSA"
}

resource "aws_key_pair" "generated" {
  depends_on = [tls_private_key.default]
  key_name   = "${var.company}_${var.environment}"
  public_key = tls_private_key.default.public_key_openssh
}

resource "aws_secretsmanager_secret" "pem" {
  name        = "${"${var.company}_${var.environment}"}-${random_string.name.result}"
  description = "Keypair (${"${var.company}_${var.environment}"}) - private key"
  tags        = local.tags
}
resource "aws_secretsmanager_secret_version" "pem" {
  secret_id     = aws_secretsmanager_secret.pem.id
  secret_string = tls_private_key.default.private_key_pem
}

resource "random_string" "name" {
  length  = 4
  special = false
}