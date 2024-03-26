
# ixo-terra-infra

## Documentation
![Terraform](https://img.shields.io/badge/Terraform-%23623CE4.svg?style=for-the-badge&logo=Terraform&logoColor=white)
![Vultr](https://img.shields.io/badge/Vultr-%230056D2.svg?style=for-the-badge&logo=Vultr&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-%23326CE5.svg?style=for-the-badge&logo=Kubernetes&logoColor=white)
![Helm](https://img.shields.io/badge/Helm-%23093D5E.svg?style=for-the-badge&logo=Helm&logoColor=white)
![Prometheus](https://img.shields.io/badge/Prometheus-%23E6522C.svg?style=for-the-badge&logo=Prometheus&logoColor=white)
![Grafana](https://img.shields.io/badge/Grafana-%23F46800.svg?style=for-the-badge&logo=Grafana&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-%23316192.svg?style=for-the-badge&logo=postgresql&logoColor=white)

This Terraform project provides Infrastructure as Code (IaC) for managing the core services and metrics deployed on VKE. 
It automates the provisioning and management of infrastructure resources required to deploy and maintain core services, applications, and associated monitoring infrastructure.

## Getting Started

These instructions will help you set up and deploy the Terraform project.

### Prerequisites

- Terraform installed on your local machine.
- Vultr Cloud Provider
- Google Cloud Platform (Optional, for unsealing Vault)

### Installation

1. Clone this repository.
2. Navigate to the project directory.
3. Run `terraform init` to initialize the project.

### Configuration

Set the following environment variable before running Terraform commands:

- `TF_VAR_vultr_api_key`: Your Vultr API key.
- `TERRAFORM_VAULT_PASSWORD`: Your Vault Password.
- `TF_VAR_oidc_argo` { clientId: "", clientSecret: "" }: (Dex -> Github clientId/secret for ArgoCD)
- `TF_VAR_oidc_vault` { clientId: "", clientSecret: "" }: (Dex -> Github clientId/secret for Vault)
- `TF_VAR_oidc_tailscale` { clientId: "", clientSecret: "" }: (Kubernetes -> Tailscale VPN clientId/secret)

### Usage

1. Make desired changes to the Terraform configuration.
2. Run `terraform plan` to see the execution plan.
3. If the plan looks good, run `terraform apply` to apply the changes.


### Additional Config After Apply
### GCP:
- `gcp-key-secret` key.json should be set to a GCP Service Account key for Vault auto-sealing.
### Vault:
- A userpass with username `Terraform` will need to be created manually with policy in `config/vault/terraform_policy_manual.hcl` for the env var `TERRAFORM_VAULT_PASSWORD`
### Cleanup

To tear down the infrastructure created by Terraform:

1. Run `terraform destroy`.
2. Confirm the action.