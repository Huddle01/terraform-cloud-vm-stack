variable "api_key" {
  type      = string
  sensitive = true
}

variable "region" {
  type = string
}

variable "base_url" {
  type        = string
  default     = null
  description = "Huddle API base URL. When null, the provider falls back to HUDDLE_BASE_URL or its built-in default."
}

variable "flavor_name" {
  type = string
}

variable "image_name" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

variable "assign_public_ip" {
  type    = bool
  default = true
}

variable "power_state" {
  type    = string
  default = "active"
}

variable "create_network" {
  type    = bool
  default = true
}

variable "network_id" {
  type    = string
  default = null
}

variable "pool_cidr" {
  type    = string
  default = null
}

variable "primary_subnet_cidr" {
  type    = string
  default = null
}

variable "primary_subnet_size" {
  type    = number
  default = null
}

variable "no_gateway" {
  type    = bool
  default = false
}

variable "enable_dhcp" {
  type    = bool
  default = true
}

variable "ingress_rules" {
  type = list(object({
    protocol = string
    port     = number
    cidr     = string
  }))
  default = []
}

variable "egress_rules" {
  type = list(object({
    protocol = string
    port     = number
    cidr     = string
  }))
  default = []
}
