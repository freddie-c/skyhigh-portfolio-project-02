variable "my_ip" {
  description = "Your public IP in CIDR notation for SSH access, e.g. 203.0.113.4/32"
  type        = string
}

variable "assets_bucket_name" {
  description = "Globally unique S3 bucket name for static assets"
  type        = string
}

