variable "name_prefix" {
  type = string
}

variable "region" {
  type = string
}

variable "flavor_id" {
  type = string
}

variable "image_id" {
  type = string
}

variable "boot_disk_size" {
  type    = number
  default = 30
}

variable "additional_volume_size" {
  type    = number
  default = null
}

variable "assign_public_ip" {
  type    = bool
  default = true
}

variable "power_state" {
  type    = string
  default = "active"
  validation {
    condition     = contains(["active", "stopped", "paused", "suspended"], var.power_state)
    error_message = "power_state must be one of: active, stopped, paused, suspended."
  }
}

variable "ssh_public_key" {
  type = string
}

variable "create_network" {
  type    = bool
  default = true
}

variable "network_id" {
  type    = string
  default = null
  validation {
    condition     = var.create_network || var.network_id != null
    error_message = "network_id must be set when create_network is false."
  }
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
  default = [
    {
      protocol = "tcp"
      port     = 22
      cidr     = "0.0.0.0/0"
    }
  ]
}
