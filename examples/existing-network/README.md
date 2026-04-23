# Example: existing-network

Attaches a VM to a pre-existing network instead of creating a new one (`create_network = false`).

Use this when:
- Multiple stacks share the same private network
- The network is managed separately (e.g. by a network team or another Terraform module)
- You want to avoid the network CIDR planning that `create_network = true` requires

## Required variables

- `huddle_api_key`
- `flavor_name` — e.g. `anton-2`
- `image_name` — e.g. `ubuntu-22.04`
- `ssh_public_key`
- `network_id` — UUID of the existing Huddle01 Cloud network

## Apply

```bash
terraform init
terraform apply \
  -var="huddle_api_key=<key>" \
  -var="flavor_name=anton-2" \
  -var="image_name=ubuntu-22.04" \
  -var="ssh_public_key=$(cat ~/.ssh/id_ed25519.pub)" \
  -var="network_id=<existing-network-uuid>"
```
