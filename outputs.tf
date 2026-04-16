output "instance_id" {
  value = huddle_cloud_instance.this.id
}

output "instance_name" {
  value = huddle_cloud_instance.this.name
}

output "instance_status" {
  value = huddle_cloud_instance.this.status
}

output "private_ipv4" {
  value     = huddle_cloud_instance.this.private_ipv4
  sensitive = true
}

output "public_ipv4" {
  value     = huddle_cloud_instance.this.public_ipv4
  sensitive = true
}

output "network_id" {
  value = local.network_id
}

output "security_group_id" {
  value = huddle_cloud_security_group.this.id
}
