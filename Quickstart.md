# Quickstart Guide for ixo-terra-infra

This setup enables a minimal configuration to get started quickly. By default, Vault is enabled for secret management, but other services (e.g., Dex, Prometheus) are optional and will require additional setup.

## Prerequisites

1. **Terraform**: Make sure Terraform is installed on your local machine.
2. **Environment Variables**: Set the necessary environment variables for services enabled in `quickstart.tfvars`.
3. **Vultr Cloud**: Make sure you have an account setup with Vultr as K8 is deployed on VKE.

## Step-by-Step Setup

### Step 1: Clone the Repository

Clone this project repository to your local machine:

```bash
git clone <repository-url>
cd ixo-terra-infra
```

### Step 2: Initialize Terraform

Initialize the Terraform project to download provider plugins and set up the backend:

```bash
terraform init
```

Create a workspace matching the name of the environment in `quickstart.tfvars`:

```bash
terraform workspace create quickstart
terraform workspace select quickstart
```

### Step 3: Configure quickstart.tfvars

#### Required Configuration

1. **Set your organization name** in `quickstart.tfvars`:
   ```hcl
   org = "my-organization"
   ```

2. **Configure your domains** in `quickstart.tfvars`:
   ```hcl
   domains = {
     primary   = "my-ixo.com"      # Replace with your primary domain
     secondary = "my-ixo.org"      # Replace with your secondary domain (optional)
   }
   ```

3. **Update DNS endpoints** in application_configs to use your domains:
   - Replace `my-ixo.com` with your actual domain throughout the file
   - Services use either `dns_prefix` (for standard patterns) or `dns_endpoint` (for custom patterns)

#### Enable Services

In the `application_configs` section, set `enabled = true` for the services you want to deploy:

```hcl
application_configs = {
  vault = {
    enabled = true # Secret management (recommended)
    domain = "primary"
    dns_prefix = "vault"
  }
  cert_manager = {
    enabled = true # Required for SSL certificates
    domain = "primary"
  }
  ingress_nginx = {
    enabled = true # Required for external access
    domain = "primary"
  }
  # Enable other services as needed...
}
```

### Step 4: Configure Environment Variables

#### Required Environment Variables

- `TF_VAR_vultr_api_key`: Your Vultr API key
- `TERRAFORM_VAULT_PASSWORD`: The password for Vault to be managed by Terraform

#### GCP Vault Auto-Unseal (Required)

Vault auto-sealing with Google Cloud Platform (GCP) requires a GCP service account key. After creating a GCP service account with the necessary permissions, save the JSON key in `gcp-key-secret` Secret in the Vault K8 namespace.

#### Optional Environment Variables

**For services like Dex, Prometheus, and Tailscale, set these only if they are enabled:**

- `TF_VAR_oidc_argo`: Contains `{ clientId: "", clientSecret: "" }` for GitHub OIDC (Dex) integration with ArgoCD
- `TF_VAR_oidc_vault`: Contains `{ clientId: "", clientSecret: "" }` for GitHub OIDC (Dex) integration with Vault
- `TF_VAR_oidc_tailscale`: Contains `{ clientId: "", clientSecret: "" }` for Tailscale VPN OIDC integration

### Step 5: Apply the Terraform Configuration

To create the infrastructure, run:

```bash
terraform apply -var-file="quickstart.tfvars"
```

Review the plan, and if it looks good, confirm to apply the changes.

---

## Application Configuration Guide

The new `application_configs` structure provides flexible DNS configuration for each service:

### DNS Configuration Options

Each service in `application_configs` supports:

- **`enabled`**: Boolean to enable/disable the service
- **`domain`**: Domain identifier (must match a key in the `domains` variable)
- **`dns_prefix`**: For standard patterns like `<prefix>.<environment>.<domain>`
- **`dns_endpoint`**: For custom DNS patterns

### DNS Pattern Examples

```hcl
# Standard pattern using dns_prefix
vault = {
  enabled = true
  domain = "primary"
  dns_prefix = "vault"  # Results in: vault.quickstart.my-ixo.com
}

# Custom pattern using dns_endpoint
prometheus_stack = {
  enabled = true
  domain = "primary"
  dns_endpoint = "monitoring.my-ixo.com"  # Custom URL
}
```

### Service Dependencies

Some services have dependencies:
- **`ingress_nginx`** is required for external access
- **`cert_manager`** is required for SSL certificates
- **`postgres_operator_crunchydata`** is required for most IXO services
- **`dex`** is required for OIDC authentication

---

## Enabled Services Guide

### Required: Vault (Secret Management)

Since Vault is enabled by default, follow these steps for initial setup:

1. **GCP Auto-Unseal**: Ensure you have a GCP service account key saved as `gcp-key-secret`
2. **Vault Password**: Set the `TERRAFORM_VAULT_PASSWORD` environment variable

After Terraform creates the infrastructure, create a user with username `Terraform` using the policy in `config/vault/terraform_policy_manual.hcl` to match the password set.

### Optional: Core Infrastructure Services

#### Dex (Authentication)
If **Dex** is enabled, configure the OIDC credentials:
- **OIDC for ArgoCD**: `TF_VAR_oidc_argo` should contain GitHub client ID and secret
- **OIDC for Vault**: `TF_VAR_oidc_vault` should contain GitHub client ID and secret

#### Prometheus Stack (Metrics & Dashboard)
If **Prometheus Stack** is enabled, it will deploy a Prometheus and Grafana stack for monitoring.

#### Tailscale (VPN)
If **Tailscale** is enabled, configure `TF_VAR_oidc_tailscale` for OIDC integration with GitHub to manage access.

#### PostgreSQL Operator (Database)
If the **PostgreSQL Operator** is enabled, it will deploy a PostgreSQL database managed by CrunchyData.

### Optional: IXO Services

Enable IXO services based on your needs:
- **Core Services**: `ixo_cellnode`, `ixo_blocksync`, `ixo_did_resolver`
- **Credential Services**: `claims_credentials_*` services
- **Assistant Services**: `ixo_faq_assistant`, `ixo_whizz`
- **Integration Services**: Matrix bots, notification server, etc.

---

## Database Configuration

### PostgreSQL Users

The `pg_ixo` configuration includes database users for different services. Add users as needed:

```hcl
pg_ixo = {
  pg_users = [
    { # Admin user - Required
      username  = "admin"
      databases = ["postgres"]
      options   = "SUPERUSER"
    },
    { # Cellnode user - Required if ixo_cellnode is enabled
      username  = "cellnode"
      databases = ["cellnode"]
    }
    # Add more users for additional services...
  ]
}
```

### Database Initialization

For existing databases, you may need to run SQL scripts in `config/sql/ixo-init.sql` if there are DB permission issues on startup for an IXO service.

---

## Monitoring Configuration

### Synthetic Monitoring

Add endpoints for health monitoring in `additional_manual_synthetic_monitoring_endpoints`:

```hcl
additional_manual_synthetic_monitoring_endpoints = {
  quickstart = [
    "https://my-service.com/health",
    "https://my-api.com/status"
  ]
}
```

### Prometheus Scraping

Configure additional Prometheus scrape targets in `additional_prometheus_scrape_metrics`:

```hcl
additional_prometheus_scrape_metrics = {
  quickstart = <<EOT
- job_name: 'my-service'
  static_configs:
    - targets: ['my-service:8080']
EOT
}
```

---

## Cleanup

To tear down the infrastructure created by Terraform:

1. Run `terraform destroy -var-file="quickstart.tfvars"`
2. Confirm the action

---

## Additional Notes

- Only configure `oidc` variables if Dex is enabled
- Vault requires setting up a GCP account for the `gcp-key-secret` to support auto-sealing
- For enabled IXO Services, you will need to login to both ArgoCD webpage to manage the deployment, and login to Vault to update environment variables & secrets
- You will need to `hard refresh` the application on ArgoCD to read changes in Vault
- Vault's root token for initial login can be found inside the Vault secret in the `vault` namespace
- ArgoCD's root admin password can be found inside the `argocd-secret` Secret in the `app-argocd` namespace

## Troubleshooting

### Common Issues

1. **DNS Resolution**: Ensure your domain is properly configured and DNS records are pointing to your cluster
2. **Certificate Issues**: Make sure `cert_manager` is enabled and properly configured
3. **Database Connection**: Verify database users are properly configured in `pg_ixo`
4. **Service Dependencies**: Check that required services (like `postgres_operator_crunchydata`) are enabled

### Logs and Monitoring

- Use ArgoCD UI to monitor application deployments
- Check Grafana (if Prometheus Stack is enabled) for system metrics
- View pod logs using `kubectl logs` for troubleshooting specific services

---
