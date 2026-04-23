# huddle01/vm-stack module

Starter module for provisioning a single VM stack on Huddle01 Cloud.

Creates:
- Optional private network
- Security group + ingress/egress rules
- Keypair
- Instance

## Storage note

The module no longer exposes `additional_volume_size`.

Use explicit volume lifecycle resources in root configuration:

1. `huddle_cloud_volume` to create/manage data disks
2. `huddle_cloud_volume_attachment` to attach/detach disks from instances

## Security Considerations

- **No ingress rules are created by default.** You must explicitly define `ingress_rules` — the module will not open any ports unless you ask it to.
- **Restrict CIDR blocks** to known IP ranges rather than `0.0.0.0/0`. Only expose ports to the internet if your workload requires it.
- **Set `assign_public_ip = false`** for internal workloads that do not need a public IP address.
- **Egress is allow-all by default** (provider default). Use `egress_rules` to restrict outbound traffic if needed.

## Usage

### Basic (create everything)

```hcl
module "vm_stack" {
  source = "huddle01/vm-stack/cloud"

  name_prefix    = "demo"
  region         = "eu2"
  flavor_name    = "anton-4"
  image_name     = "ubuntu-22.04"
  ssh_public_key = file("~/.ssh/id_ed25519.pub")

  pool_cidr           = "10.0.0.0/8"
  primary_subnet_cidr = "10.0.1.0/24"
  primary_subnet_size = 24

  ingress_rules = [
    { protocol = "tcp", port = 80,  cidr = "0.0.0.0/0" },
    { protocol = "tcp", port = 443, cidr = "0.0.0.0/0" },
  ]
}
```

### Use an existing network

```hcl
module "vm_stack" {
  source = "huddle01/vm-stack/cloud"

  name_prefix    = "app"
  region         = "eu2"
  flavor_name    = "anton-4"
  image_name     = "ubuntu-22.04"
  ssh_public_key = file("~/.ssh/id_ed25519.pub")

  create_network = false
  network_id     = "existing-network-uuid"

  ingress_rules = [
    { protocol = "tcp", port = 443, cidr = "0.0.0.0/0" },
  ]
}
```

### Internal workload (no public IP, restricted egress)

```hcl
module "vm_stack" {
  source = "huddle01/vm-stack/cloud"

  name_prefix      = "internal"
  region           = "eu2"
  flavor_name      = "anton-2"
  image_name       = "ubuntu-22.04"
  ssh_public_key   = file("~/.ssh/id_ed25519.pub")
  assign_public_ip = false

  pool_cidr           = "10.0.0.0/8"
  primary_subnet_cidr = "10.0.2.0/24"
  primary_subnet_size = 24

  egress_rules = [
    { protocol = "tcp", port = 443, cidr = "0.0.0.0/0" },
  ]
}
```

## Input Variables

| Name | Type | Default | Required | Description |
|------|------|---------|----------|-------------|
| `name_prefix` | `string` | — | yes | Prefix applied to all resource names |
| `region` | `string` | — | yes | Huddle01 Cloud region (e.g. `eu2`) |
| `flavor_name` | `string` | — | yes | Instance flavor name (e.g. `anton-2`, `anton-4`) |
| `image_name` | `string` | — | yes | OS image name to boot from (e.g. `ubuntu-22.04`) |
| `ssh_public_key` | `string` | — | yes | OpenSSH public key for SSH access |
| `boot_disk_size` | `number` | `30` | no | Boot disk size in GB (must be > 0) |
| `assign_public_ip` | `bool` | `true` | no | Assign a public IPv4 address |
| `power_state` | `string` | `"active"` | no | Desired power state: `active`, `stopped`, `paused`, `suspended` |
| `create_network` | `bool` | `true` | no | Create a new private network for the instance |
| `network_id` | `string` | `null` | no | Existing network ID; required when `create_network = false` |
| `pool_cidr` | `string` | `null` | no | Floating IP pool CIDR; required when `create_network = true` |
| `primary_subnet_cidr` | `string` | `null` | no | Primary subnet CIDR; required when `create_network = true` |
| `primary_subnet_size` | `number` | `null` | no | Primary subnet prefix length; required when `create_network = true` |
| `no_gateway` | `bool` | `false` | no | Disable default gateway on the subnet |
| `enable_dhcp` | `bool` | `true` | no | Enable DHCP on the primary subnet |
| `ingress_rules` | `list(object)` | `[]` | no | Inbound firewall rules (protocol, port, cidr) |
| `egress_rules` | `list(object)` | `[]` | no | Outbound firewall rules (protocol, port, cidr). Empty = provider default (allow all) |

## Outputs

| Name | Sensitive | Description |
|------|-----------|-------------|
| `instance_id` | no | Unique identifier of the created instance |
| `instance_name` | no | Name of the created instance |
| `instance_status` | no | Current power state of the instance |
| `private_ipv4` | yes | Private IPv4 address within the attached network |
| `public_ipv4` | yes | Public IPv4 address (empty if `assign_public_ip = false`) |
| `network_id` | no | ID of the network the instance is attached to |
| `security_group_id` | no | ID of the security group attached to the instance |

## Limitations

- Provisions a **single instance** per module invocation. For multiple VMs use `count` or `for_each` at the root level.
- Supports **single-port rules only** — each rule maps to one port. For port ranges, add multiple rules.
- Data volumes must be managed separately with `huddle_cloud_volume` and `huddle_cloud_volume_attachment`.
- No built-in load balancing or auto-scaling.
