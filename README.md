# ixo-terra-infra

## Documentation
![Terraform](https://img.shields.io/badge/Terraform-%23623CE4.svg?style=for-the-badge&logo=Terraform&logoColor=white)
![Vultr](https://img.shields.io/badge/Vultr-%230056D2.svg?style=for-the-badge&logo=Vultr&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-%23326CE5.svg?style=for-the-badge&logo=Kubernetes&logoColor=white)
![Helm](https://img.shields.io/badge/Helm-%23093D5E.svg?style=for-the-badge&logo=Helm&logoColor=white)
![Prometheus](https://img.shields.io/badge/Prometheus-%23E6522C.svg?style=for-the-badge&logo=Prometheus&logoColor=white)
![Grafana](https://img.shields.io/badge/Grafana-%23F46800.svg?style=for-the-badge&logo=Grafana&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-%23316192.svg?style=for-the-badge&logo=postgresql&logoColor=white)

This Terraform project provides Infrastructure as Code (IaC) for managing core services and monitoring infrastructure on Kubernetes. It automates the provisioning and management of infrastructure resources required to deploy and maintain applications with comprehensive monitoring, security, and observability tools.

## 💰 Cost Estimation

**Before deploying**: Understanding infrastructure costs is crucial for any project. This repository includes comprehensive cost estimation tools to help you budget and optimize your infrastructure spending.

### Quick Cost Overview

| Environment Type | Monthly Cost | What's Included |
|------------------|-------------|-----------------|
| **Development** | ~$74/month | Basic setup with minimal resources |
| **Testing/Staging** | ~$294/month | Full stack with cross-chain validators |
| **Production** | ~$308/month | Full stack with high availability |

### 📋 Cost Documentation

- **[README-cost-estimation.md](README-cost-estimation.md)** - Complete cost estimation guide
  - How to run cost estimates before deployment
  - Interactive tools for different environments
  - Cost optimization strategies
  - CI/CD integration for automatic cost tracking

- **[README-vultr-cost-estimates.md](README-vultr-cost-estimates.md)** - Detailed cost breakdowns
  - Environment-specific cost analysis
  - Vultr vs AWS cost comparisons
  - Infrastructure component pricing
  - Annual cost projections

### 🚀 Quick Cost Estimation

```bash
# Run cost estimate for your development environment
./estimate-costs.sh your_dev_env

# Compare costs between environments
./estimate-costs.sh compare

# Generate comprehensive cost reports
./estimate-costs.sh report
```

**For contributors**: These tools help you understand the cost impact of infrastructure changes before proposing them. See the cost estimation documentation for detailed instructions.

## What This Project Provides

This infrastructure stack automatically deploys and manages:

- **Kubernetes Cluster**: Multi-cloud support (Vultr VKE or AWS EKS)
- **GitOps Deployment**: ArgoCD for automated application deployment
- **Monitoring Stack**: Prometheus, Grafana, Loki for metrics and logging
- **Security & Authentication**: Vault for secrets management, Dex for OAuth
- **Database Management**: PostgreSQL clusters with automated backups
- **Networking**: Ingress controllers, DNS management, VPN access
- **Additional Services**: Matrix chat, Ghost CMS, Uptime monitoring

## Prerequisites

### Required Tools
Install these tools on your development machine:

1. **Terraform CLI** (v1.0+)
   - Download from: https://terraform.io/downloads
   - Verify installation: `terraform --version`

2. **kubectl** (Kubernetes CLI)
   - Download from: https://kubernetes.io/docs/tasks/tools/install-kubectl/
   - Used to interact with your Kubernetes cluster

3. **Git**
   - For cloning repositories and GitOps workflows

### Required Third-Party Accounts

You'll need accounts with the following services:

#### Essential Services
1. **Cloud Provider** (choose one):
   - **Vultr**: For VKE (Vultr Kubernetes Engine) - Recommended for simplicity
   - **AWS**: For EKS (Elastic Kubernetes Service) - More enterprise features

2. **GitHub**:
   - Used for OAuth authentication and storing your configuration repositories
   - You'll need to create OAuth Apps for ArgoCD and Vault integration

#### Optional Services (depending on features you enable)
3. **Google Cloud Platform**:
   - Required for Vault auto-unsealing and storage backups
   - Create a service account with appropriate permissions

4. **Cloudflare**:
   - For DNS management (if using external-dns with Cloudflare)
   - Alternative to manual DNS configuration

5. **Tailscale**:
   - For secure VPN access to your cluster
   - Create OAuth credentials for Kubernetes integration

## Getting Started

### 1. Clone and Setup

```bash
# Clone this repository
git clone <repository-url>
cd ixo-terra-infra

# Initialize Terraform
terraform init
```

### 2. Estimate Costs First

**Important**: Before deploying, run cost estimates to understand your monthly expenses:

```bash
# Make cost estimation script executable
chmod +x estimate-costs.sh

# Estimate costs for your development environment
./estimate-costs.sh your_dev_env

# For detailed cost breakdowns, see:
# - README-cost-estimation.md (how to run estimates)
# - README-vultr-cost-estimates.md (detailed pricing)
```

### 3. Create Your Configuration

**Important**: Don't use the existing `terraform.tfvars` file directly - it's configured for our specific infrastructure. Instead, create your own configuration files:

```bash
# Create your own variables file
cp terraform.tfvars my-infrastructure.tfvars
# OR use the quickstart example
cp quickstart.tfvars my-infrastructure.tfvars

# Edit the file with your specific configuration
nano my-infrastructure.tfvars
```

### 4. Configure Environment Variables

Set these environment variables before running Terraform:

#### Essential Variables
```bash
# Your cloud provider API key
export TF_VAR_vultr_api_key="your-vultr-api-key"
# OR for AWS:
export AWS_ACCESS_KEY_ID="your-aws-access-key"
export AWS_SECRET_ACCESS_KEY="your-aws-secret-key"

# Vault master password (choose a strong password)
export TERRAFORM_VAULT_PASSWORD="your-secure-vault-password"
```

#### OAuth Configuration (for authentication)
```bash
# GitHub OAuth for ArgoCD (create at: https://github.com/settings/applications/new)
export TF_VAR_oidc_argo='{"clientId": "your-github-app-client-id", "clientSecret": "your-github-app-secret"}'

# GitHub OAuth for Vault (create a separate GitHub OAuth app)
export TF_VAR_oidc_vault='{"clientId": "your-vault-github-client-id", "clientSecret": "your-vault-github-secret"}'
```

#### Optional Variables
```bash
# Tailscale OAuth (if enabling Tailscale VPN)
export TF_VAR_oidc_tailscale='{"clientId": "your-tailscale-client-id", "clientSecret": "your-tailscale-secret"}'

# Cloudflare API token (if using Cloudflare DNS)
export TF_VAR_cloudflare_api_token="your-cloudflare-token"
```

### 5. Understanding Environment Configuration

This project uses a flexible environment system defined in `variables.tf`. Each environment (dev, staging, prod, etc.) can have different services enabled or disabled.

> **Environment Naming**: You can use any environment names that make sense for your organization (e.g., `companyname_dev`, `staging`, `production`, etc.). The examples below use generic names, but you'll see IXO-specific names (`devnet`, `testnet`, `mainnet`) in our configuration as reference.

#### How `var.environments` Works

In your `.tfvars` file, you define environments like this:

```hcl
# First, define your domain mappings
domains = {
  yourdomain = "yourdomain.com"     # Your primary domain
  secondary  = "secondary.com"      # Optional secondary domain
}

environments = {
  "your_dev" = {                    # Use your own naming convention
    cluster_firewall = true
    aws_region      = "us-west-2"   # or your preferred AWS region
    aws_iam_users   = []            # List of AWS IAM users for this environment
    rpc_url         = "https://dev.yourdomain.com/rpc/"
    ipfs_service_mapping = "https://ipfs.yourdomain.com"
    is_development  = true          # Optional: enables development-specific settings
    
    # AWS VPC configuration
    aws_vpc_config = {
      nat_gateway_enabled = false   # Set to true for production
      flow_logs_enabled = false     # Set to true for production
      retention_days = 7            # Log retention period
      az_count = 2                  # Number of availability zones
    }
    
    # Hyperlane configuration (if using cross-chain features)
    hyperlane = {
      chain_names     = [""]        # Your chain identifiers
      metadata_chains = [""]        # Metadata chain identifiers
    }
    
    # Enable/disable and configure services for this environment
    application_configs = {
      # Core Infrastructure (recommended to keep enabled)
      "cert_manager" = {
        enabled = true
        domain = "yourdomain"       # References domains defined above
      }
      "ingress_nginx" = {
        enabled = true
        domain = "yourdomain"
      }
      "prometheus_stack" = {
        enabled = true
        domain = "yourdomain"
        dns_endpoint = "monitoring.yourdomain.com"  # Custom monitoring URL
      }
      "vault" = {
        enabled = true
        domain = "yourdomain"
        dns_prefix = "vault"        # Creates vault.yourdomain.com
      }
      "dex" = {
        enabled = true
        domain = "yourdomain"
        dns_prefix = "dex"          # Creates dex.yourdomain.com
      }
      
      # Database services
      "postgres_operator_crunchydata" = {
        enabled = true
        domain = "yourdomain"
      }
      
      # Optional services (disable in dev to save resources)
      "loki" = {
        enabled = false             # Log aggregation - disable in dev
        domain = "yourdomain"
      }
      "matrix" = {
        enabled = false             # Chat server - disable in dev
        domain = "yourdomain"
        dns_endpoint = "chat.yourdomain.com"
      }
      "ghost" = {
        enabled = false             # CMS - disable in dev
        domain = "yourdomain"
        dns_prefix = "blog"
      }
      
      # Services with storage requirements
      "uptime_kuma" = {
        enabled = true
        domain = "yourdomain"
        dns_endpoint = "status.yourdomain.com"
      }
      
      # Services with custom storage settings
      "your_custom_service" = {
        enabled = true
        domain = "yourdomain"
        dns_endpoint = "custom.yourdomain.com"
        storage_class = "bulk"      # Use cheaper storage
        storage_size = "40Gi"       # Storage allocation
      }
      
      # ... more services as needed
    }
  }
  
  "your_prod" = {                   # Production environment
    cluster_firewall = true
    aws_region      = "us-east-1"
    aws_iam_users   = ["admin1", "admin2"]  # Production admin users
    rpc_url         = "https://prod.yourdomain.com/rpc/"
    ipfs_service_mapping = "https://ipfs.yourdomain.com"
    is_development  = false         # Production settings enabled
    
    aws_vpc_config = {
      nat_gateway_enabled = true    # Enable for production security
      flow_logs_enabled = true      # Enable for production monitoring
      retention_days = 30           # Longer retention for production
      az_count = 3                  # More AZs for high availability
    }
    
    hyperlane = {
      chain_names     = ["mainnet", "ethereum"]
      metadata_chains = ["mainnet", "ethereum"]
    }
    
    application_configs = {
      # Core services (same as dev but with production settings)
      "cert_manager" = {
        enabled = true
        domain = "yourdomain"
      }
      "ingress_nginx" = {
        enabled = true
        domain = "yourdomain"
      }
      "prometheus_stack" = {
        enabled = true
        domain = "yourdomain"
        dns_endpoint = "monitoring.yourdomain.com"
      }
      
      # Enable additional services in production
      "loki" = {
        enabled = true              # Enable log aggregation in prod
        domain = "yourdomain"
      }
      "matrix" = {
        enabled = true              # Enable chat server in prod
        domain = "yourdomain"
        dns_endpoint = "chat.yourdomain.com"
      }
      "ghost" = {
        enabled = true              # Enable CMS in prod
        domain = "yourdomain"
        dns_prefix = "blog"
      }
      
      # ... more services
    }
  }
}
```

#### Key Configuration Options

**Per-Environment Settings:**
- `cluster_firewall`: Enable/disable cluster firewall protection
- `aws_region`: AWS region for resources (if using AWS)
- `aws_iam_users`: List of IAM users with access to this environment
- `is_development`: Boolean flag that enables development-specific optimizations
  - Reduces resource requirements
  - Enables additional logging
  - Configures less strict security settings
- `rpc_url`: Blockchain RPC endpoint for this environment
- `aws_vpc_config`: VPC networking configuration
- `hyperlane`: Cross-chain bridge configuration

**Per-Service Settings:**
- `enabled`: Whether to deploy this service in this environment
- `domain`: Which domain mapping to use (references `domains` at top of file)
- `dns_endpoint`: Complete custom URL (e.g., "api.yourdomain.com")
- `dns_prefix`: Prefix to add to domain (e.g., "api" creates "api.yourdomain.com")
- `storage_class`: Storage type ("standard", "fast", "bulk")
- `storage_size`: Storage allocation (e.g., "40Gi", "100Gi")

#### Available Services

You can enable/disable these services in any environment:

- `argocd`: GitOps deployment tool (recommended: always enabled)
- `prometheus_stack`: Monitoring with Prometheus and Grafana
- `cert_manager`: Automatic SSL certificate management
- `ingress_nginx`: Load balancer and ingress controller
- `vault`: Secrets management
- `dex`: OAuth2/OIDC authentication
- `loki`: Log aggregation and management
- `postgres_operator_crunchydata`: PostgreSQL database clusters
- `matrix`: Matrix chat server
- `ghost`: Ghost CMS blogging platform
- `tailscale`: VPN access to cluster
- `uptime_kuma`: Uptime monitoring
- `metrics_server`: Kubernetes metrics
- `external_dns_cloudflare`: Automatic DNS management

### 6. Deploy Your Infrastructure

```bash
# Create or select workspace (environment) - use your own naming
terraform workspace new your_dev_env
# OR
terraform workspace select your_dev_env

# Plan your deployment
terraform plan -var-file="my-infrastructure.tfvars"

# Apply the changes
terraform apply -var-file="my-infrastructure.tfvars"
```

### 7. Post-Deployment Configuration

After successful deployment, you may need to configure:

#### Google Cloud Platform (if using GCP features)
- Upload your GCP service account key as `gcp-key-secret` in the appropriate namespace
- The key should have permissions for KMS and Cloud Storage

#### Vault Configuration
- A userpass auth method with username `Terraform` needs to be created manually (this will be automated in future)
- Apply the policy from `config/vault/terraform_policy_manual.hcl`
- This allows Terraform to manage Vault resources

#### DNS Configuration
- If not using external-dns, manually configure DNS records to point to your load balancer
- Check the ingress controller service for the external IP

## Customization

### Adding New Services

To add a new service:

1. Create a new module in `modules.tf`
2. Add the service to the `application_configs` in your environment
3. Create appropriate Helm values in `config/helm-values/`

### Environment-Specific Configuration

Each environment can have different:
- Cloud providers
- Resource sizes
- Enabled services
- DNS configurations
- Security settings

### Multi-Environment Setup

You can manage multiple environments from the same Terraform configuration:

```bash
# Development environment
terraform workspace select your_dev
terraform apply -var-file="your-dev.tfvars"

# Production environment  
terraform workspace select your_prod
terraform apply -var-file="your-prod.tfvars"
```

## Cleanup

To remove all infrastructure:

```bash
terraform workspace select your-environment
terraform destroy -var-file="my-infrastructure.tfvars"
```

**Warning**: This will permanently delete all resources. Make sure you have backups of any important data.

## Troubleshooting

### Common Issues

1. **Authentication Errors**: Verify your API keys and OAuth configuration
2. **Resource Limits**: Check your cloud provider account limits
3. **DNS Issues**: Ensure DNS records are properly configured
4. **Service Dependencies**: Some services depend on others (e.g., applications need ArgoCD)

### Getting Help

- Check Terraform logs: `terraform apply` with `-v` flag for verbose output
- Verify Kubernetes cluster: `kubectl get nodes`
- Check ArgoCD applications: Access ArgoCD UI to see deployment status

## Security Notes

- Store sensitive variables in environment variables, not in `.tfvars` files
- Use strong passwords for Vault and other services
- Regularly rotate API keys and secrets
- Enable only the services you need for each environment
- Consider using private repositories for your customized configuration