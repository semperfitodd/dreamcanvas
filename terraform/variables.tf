variable "company" {
  description = "Company name"
  type        = string
  default     = null
}

variable "domain" {
  description = "Domain"
  type        = string
  default     = null
}

variable "openvpn_instance_type" {
  description = "Instance type for OpenVPN instance"
  type        = string
  default     = null
}

variable "region" {
  description = "AWS Region where resources will be deployed"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to be applied to resources"
  type        = map(string)
  default     = {}
}
