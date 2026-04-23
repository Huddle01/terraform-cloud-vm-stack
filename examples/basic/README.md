# Example: basic

Provisions a complete VM stack — network, security group, keypair, and instance — with a public IP and SSH/HTTP/HTTPS ingress open.

Use this as a starting point. In production, restrict `ingress_rules` CIDRs to known IP ranges.

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
