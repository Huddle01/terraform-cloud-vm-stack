# huddle01/vm-stack module

Starter module for provisioning a single VM stack on Huddle01 Cloud.

Creates:
- Optional private network
- Security group + ingress rules
- Keypair
- Instance

## Storage note

The module no longer exposes `additional_volume_size`.

Use explicit volume lifecycle resources in root configuration:

1. `huddle_cloud_volume` to create/manage data disks
2. `huddle_cloud_volume_attachment` to attach/detach disks from instances

## Usage

```hcl
module "vm_stack" {
  source = "huddle01/vm-stack/cloud"

  name_prefix    = "demo"
  region         = "eu2"
  flavor_id      = "anton-4"
  image_id       = "ubuntu-22.04"
  ssh_public_key = file("~/.ssh/id_ed25519.pub")
}
```
