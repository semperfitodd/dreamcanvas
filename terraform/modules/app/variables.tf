locals {
  tags = merge(var.tags, {
    environment = var.environment
  })
}

variable "app_namespace" {
  description = "Namespace where the Gen AI images will be deployed"
  type        = string
}

variable "apps" {
  description = "Map containing information for each agent"
  type        = map(any)
}

variable "company" {
  description = "Company name"
  type        = string
}

variable "domain" {
  description = "Domain"
  type        = string
}

variable "eks_cluster_version" {
  description = "Version of kubernetes running on cluster"
  type        = string
}

variable "eks_node_instance_type" {
  description = "Instance type for EKS worker node managed group"
  type        = string
}

variable "environment" {
  description = "Environment all resources will be built"
  type        = string
}

variable "openvpn_sg" {
  description = "OpenVPN Security Group ID"
  type        = string
}

variable "site_directory" {
  description = "local location of site build"
  type        = string
}

variable "tags" {
  description = "Tags to be applied to resources"
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "vpc_redundancy" {
  description = "Redundancy for NAT gateways"
  type        = bool
  default     = true
}

variable "web_acl_id" {
  description = "WAF ARN"
  type        = string
}
