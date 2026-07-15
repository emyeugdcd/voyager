variable "location" {
  type    = string
  default = "northeurope"
}

variable "project" {
  type    = string
  default = "voyager"
}

variable "environment" {
  type    = string
  default = "test"
}

variable "ssh_public_key" {
  type        = string
  description = "Public key for SSH access to the jumphost."
}

variable "domain_name" {
  type        = string
  default     = "voyager-cloud.com"
  description = "Domain name for DNS zones."
}
