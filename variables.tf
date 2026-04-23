variable "name_prefix" {
  type        = string
  description = "Prefix applied to all resource names (network, security group, keypair, instance)."
}

variable "region" {
  type        = string
  description = "Huddle01 Cloud region where resources will be created (e.g. 'eu2', 'us-east')."
}

variable "flavor_name" {
  type        = string
  description = "Name of the instance flavor to use for the VM (e.g. 'anton-2', 'anton-4')."
}

variable "image_name" {
  type        = string
  description = "Name of the OS image to boot the instance from (e.g. 'ubuntu-22.04')."
}

variable "boot_disk_size" {
  type        = number
  default     = 30
  description = "Size of the boot disk in GB. Must be greater than 0."
  validation {
    condition     = var.boot_disk_size > 0
    error_message = "boot_disk_size must be greater than 0."
  }
}

variable "assign_public_ip" {
  type        = bool
  default     = true
  description = "Whether to assign a public IPv4 address to the instance. Set to false for internal workloads."
}

variable "power_state" {
  type        = string
  default     = "active"
  description = "Desired power state of the instance. One of: active, stopped, paused, suspended."
  validation {
    condition     = contains(["active", "stopped", "paused", "suspended"], var.power_state)
    error_message = "power_state must be one of: active, stopped, paused, suspended."
  }
}

variable "ssh_public_key" {
  type        = string
  description = "OpenSSH public key to inject into the instance for SSH access (ssh-rsa, ssh-ed25519, or ecdsa-sha2-nistp256)."
  validation {
    condition     = can(regex("^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256) \\S+", var.ssh_public_key))
    error_message = "ssh_public_key must be a valid OpenSSH public key starting with ssh-rsa, ssh-ed25519, or ecdsa-sha2-nistp256."
  }
}

variable "create_network" {
  type        = bool
  default     = true
  description = "When true, a new private network is created for the instance. When false, network_id must be provided."
}

variable "network_id" {
  type        = string
  default     = null
  description = "ID of an existing network to attach the instance to. Required when create_network is false."
  validation {
    condition     = var.create_network || var.network_id != null
    error_message = "network_id must be set when create_network is false."
  }
}

variable "pool_cidr" {
  type        = string
  default     = null
  description = "Floating IP pool CIDR for the new network. Required when create_network is true."
}

variable "primary_subnet_cidr" {
  type        = string
  default     = null
  description = "CIDR block for the primary subnet (e.g. '10.0.0.0/24'). Required when create_network is true."
}

variable "primary_subnet_size" {
  type        = number
  default     = null
  description = "Prefix length for the primary subnet (e.g. 24). Required when create_network is true."
}

variable "no_gateway" {
  type        = bool
  default     = false
  description = "When true, no default gateway is set on the subnet. Useful for isolated internal networks."
}

variable "enable_dhcp" {
  type        = bool
  default     = true
  description = "Whether to enable DHCP on the primary subnet."
}

variable "ingress_rules" {
  type = list(object({
    protocol = string
    port     = number
    cidr     = string
  }))
  default     = []
  description = "List of inbound firewall rules. Each rule specifies a protocol (tcp/udp/icmp), port (1–65535), and source CIDR."
  validation {
    condition = alltrue([
      for rule in var.ingress_rules : (
        rule.port >= 1 && rule.port <= 65535 &&
        contains(["tcp", "udp", "icmp"], rule.protocol) &&
        can(cidrhost(rule.cidr, 0))
      )
    ])
    error_message = "Each ingress rule must have port 1–65535, protocol tcp/udp/icmp, and a valid CIDR (e.g. '10.0.0.0/8')."
  }
}

variable "egress_rules" {
  type = list(object({
    protocol = string
    port     = number
    cidr     = string
  }))
  default     = []
  description = "List of outbound firewall rules. Defaults to empty (provider default allows all egress). Each rule specifies a protocol (tcp/udp/icmp), port (1–65535), and destination CIDR."
  validation {
    condition = alltrue([
      for rule in var.egress_rules : (
        rule.port >= 1 && rule.port <= 65535 &&
        contains(["tcp", "udp", "icmp"], rule.protocol) &&
        can(cidrhost(rule.cidr, 0))
      )
    ])
    error_message = "Each egress rule must have port 1–65535, protocol tcp/udp/icmp, and a valid CIDR (e.g. '0.0.0.0/0')."
  }
}
