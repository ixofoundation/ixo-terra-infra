
# Quickstart Guide for ixo-terra-infra

Welcome to the quickstart guide! This setup enables a minimal configuration to get started quickly. By default, Vault is enabled for secret management, but other services (e.g., Dex, Prometheus) are optional.

## Prerequisites

1. **Terraform**: Make sure Terraform is installed on your local machine.
2. **Environment Variables**: Set the necessary environment variables for services enabled in `quickstart.tfvars`.

## Step-by-Step Setup

### Step 1: Clone the Repository

Clone this project repository to your local machine:

### Step 2: Initialize Terraform

Initialize the Terraform project to download provider plugins and set up the backend:

```bash
terraform init
```
Create a workspace matching the name of the environment in `quickstart.tfvars`
```bash
terraform workspace create quickstart
terraform workspace select quickstart
```

### Step 3: Configure Environment Variables

#### Required Environment Variables

- `TF_VAR_vultr_api_key`: Your Vultr API key.
- `TERRAFORM_VAULT_PASSWORD`: The password for Vault to be managed by Terraform.

#### GCP Vault Auto-Unseal (Required)

Vault auto-sealing with Google Cloud Platform (GCP) requires a GCP service account key. After creating a GCP service account with the necessary permissions, save the JSON key in `gcp-key-secret` Secret in the Vault K8 namespace.

#### Optional Environment Variables

**For services like Dex, Prometheus, and Tailscale, set these only if they are enabled:**

- `TF_VAR_oidc_argo`: Contains `{ clientId: "", clientSecret: "" }` for GitHub OIDC (Dex) integration with ArgoCD.
- `TF_VAR_oidc_vault`: Contains `{ clientId: "", clientSecret: "" }` for GitHub OIDC (Dex) integration with Vault.
- `TF_VAR_oidc_tailscale`: Contains `{ clientId: "", clientSecret: "" }` for Tailscale VPN OIDC integration.

### Step 4: Apply the Terraform Configuration
Enable any IXO services you wish to use in `quickstart.tfvars`
*Note that some services will require the Database to be enabled.*
### Step 5: Apply the Terraform Configuration

To create the infrastructure, run:

```bash
terraform apply -var-file="quickstart.tfvars"
```

Review the plan, and if it looks good, confirm to apply the changes.

---

## Enabled Services Guide

Here’s a breakdown of additional configurations required based on the enabled services in `quickstart.tfvars`:

### Required: Vault (Secret Management)

Since Vault is enabled by default, follow these steps for initial setup:

1. **GCP Auto-Unseal**: Ensure you have a GCP service account key saved as `gcp-key-secret`.
2. **Vault Password**: Set the `TERRAFORM_VAULT_PASSWORD` environment variable.

After Terraform creates the infrastructure, create a user with username `Terraform` using the policy in `config/vault/terraform_policy_manual.hcl` to match the password set.

### Optional: Dex (Authentication)

If **Dex** is enabled, configure the OIDC credentials:

- **OIDC for ArgoCD**: `TF_VAR_oidc_argo` should contain GitHub client ID and secret.
- **OIDC for Vault**: `TF_VAR_oidc_vault` should contain GitHub client ID and secret.

### Optional: Prometheus Stack (Metrics & Dashboard)

If **Prometheus Stack** is enabled, it will deploy a Prometheus and Grafana stack for monitoring.

### Optional: Tailscale (VPN)

If **Tailscale** is enabled, configure `TF_VAR_oidc_tailscale` for OIDC integration with GitHub to manage access.

### Optional: PostgreSQL Operator (Database)

If the **PostgreSQL Operator** is enabled, it will deploy a PostgreSQL database managed by CrunchyData.

---

## Cleanup

To tear down the infrastructure created by Terraform:

1. Run `terraform destroy`.
2. Confirm the action.

---

## Additional Notes

- Only configure `oidc` variables if Dex is enabled.
- Vault requires setting up a GCP account for the `gcp-key-secret` to support auto-sealing.
- For enabled IXO Services, you will need to login to both ArgoCD webpage to manage the deployment, and login to Vault to update environment variables & secrets, you will need to `hard refresh` the application on ArgoCD to read changes in Vault.
- Vault's root token for initial login can be found inside the Vault secret in the `vault` namespace.
- ArgoCD's root admin password can be found inside the `argocd-secret` Secret in the `app-argocd` namespace.

---
