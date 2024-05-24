output "public_subnets" {
  value = module.vpc.public_subnets
}

output "s3_app_bucket" {
  value = module.app_s3_bucket.s3_bucket_id
}

output "ssh_keypair" {
  value = aws_key_pair.generated.key_name
}

output "vpc_id" {
  value = module.vpc.vpc_id
}