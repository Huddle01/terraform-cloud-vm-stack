# Example: private-vm

Provisions a VM with no public IP address and locked-down egress — the recommended pattern for internal workloads (databases, queues, background workers) that should not be directly reachable from the internet.

Key settings:
- `assign_public_ip = false` — no public IPv4 allocated
- No `ingress_rules` — all inbound traffic blocked at the security group level
- `egress_rules` restricted to HTTPS + DNS only

Access the VM through a bastion host, VPN, or another instance on the same network.

## Required variables

- `huddle_api_key`
- `flavor_name` — e.g. `anton-2`
- `image_name` — e.g. `ubuntu-22.04`
- `ssh_public_key`

## Apply

```bash
terraform init
terraform apply \
  -var="huddle_api_key=<key>" \
  -var="flavor_name=anton-2" \
  -var="image_name=ubuntu-22.04" \
  -var="ssh_public_key=$(cat ~/.ssh/id_ed25519.pub)"
```
