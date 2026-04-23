output "instance_id" {
  value       = huddle_cloud_instance.this.id
  description = "Unique identifier of the created instance."
}

output "instance_name" {
  value       = huddle_cloud_instance.this.name
  description = "Name of the created instance."
}

output "instance_status" {
  value       = huddle_cloud_instance.this.power_state
  description = "Current power state of the instance (e.g. 'active', 'stopped')."
}

output "private_ipv4" {
  value       = huddle_cloud_instance.this.private_ipv4
  sensitive   = true
  description = "Private IPv4 address of the instance within the attached network."
}

output "public_ipv4" {
  value       = huddle_cloud_instance.this.public_ipv4
  sensitive   = true
  description = "Public IPv4 address assigned to the instance. Empty string if assign_public_ip is false."
}

output "network_id" {
  value       = local.network_id
  description = "ID of the network the instance is attached to (created or pre-existing)."
}

output "security_group_id" {
  value       = huddle_cloud_security_group.this.id
  description = "ID of the security group attached to the instance."
}
