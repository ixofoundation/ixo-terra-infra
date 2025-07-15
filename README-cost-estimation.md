# IXO Terra Infrastructure Cost Estimation

This repository includes comprehensive cost estimation tools for the IXO Terra infrastructure using Infracost and manual calculations for Vultr services.

> **For non-DevOps developers**: This guide helps you understand and estimate infrastructure costs before deployment. The tools are designed to be easy to use - no deep infrastructure knowledge required!

## 💰 Quick Cost Overview

| Environment Type | Monthly Cost | What You Get |
|------------------|-------------|--------------|
| **Development** | ~$74/month | Basic setup with minimal resources for testing |
| **Testing/Staging** | ~$294/month | Full stack with cross-chain validators for staging |
| **Production** | ~$308/month | Full stack with high availability for live services |

> **Environment Naming**: You can use any environment names that make sense for your organization (e.g., `mycompany_dev`, `staging`, `production`, etc.). In our examples, we reference both generic names and IXO-specific names (`devnet`, `testnet`, `mainnet`) for reference.

## 🚀 Quick Start

### Prerequisites

1. **Infracost CLI** (already installed)
2. **Terraform** (already configured)
3. **Google Cloud credentials** (already configured)
4. **Infracost API key** (already configured)

### Running Cost Estimates

```bash
# Make the script executable
chmod +x estimate-costs.sh

# Estimate costs for your environments (use your own naming)
./estimate-costs.sh your_dev        # Your development environment
./estimate-costs.sh your_staging    # Your staging environment
./estimate-costs.sh your_prod       # Your production environment

# Or using IXO reference examples:
./estimate-costs.sh devnet          # IXO development environment
./estimate-costs.sh testnet         # IXO testing environment
./estimate-costs.sh mainnet         # IXO production environment

# Compare costs between environments
./estimate-costs.sh compare

# Generate comprehensive reports
./estimate-costs.sh report

# Run complete cost analysis
./estimate-costs.sh all
```

## 📋 Cost Estimation Files

### 1. `infracost.yml`
Main configuration file that defines:
- Multiple environments (configurable for your organization)
- Terraform workspaces
- Variable files
- Output formats

> **Note**: The included `infracost.yml` uses IXO-specific environment names. You'll want to modify it for your own environment names.

### 2. `infracost-usage.yml`
Usage patterns file that defines:
- Storage usage (500GB-2TB across services)
- Database query patterns (10M queries/month)
- Network transfer estimates
- API operation counts

### 3. `estimate-costs.sh`
Interactive script that provides:
- Environment-specific cost estimates
- Cost comparisons between environments
- HTML and JSON report generation
- Automated cost calculations

### 4. `README-vultr-cost-estimates.md`
Comprehensive cost breakdown including:
- Vultr VKE pricing (not covered by Infracost)
- GCS storage costs with lifecycle policies
- Environment-specific totals
- AWS cost comparisons

## 🔍 Understanding the Results

### What Infracost Shows You

The cost estimates include:
- **Google Cloud Storage**: Backup storage with lifecycle policies
- **Google Cloud KMS**: Encryption keys for security
- **AWS Services**: If using AWS (EKS, ECS, etc.)
- **Usage-based costs**: Based on realistic usage patterns

### What's Missing (Vultr Costs)

Infracost doesn't include Vultr VKE costs, so we calculate them separately:
- **Vultr VKE Control Plane**: $10/month per cluster
- **Vultr Worker Nodes**: $24-32/month per node
- **Vultr Block Storage**: $0.10/GB/month

> **Important**: Always check `README-vultr-cost-estimates.md` for the complete picture!

## 📊 Cost Breakdown by Environment Type

### Development Environment (~$74/month)
- **Infracost Results**: $6.22/month (GCP services only)
- **Vultr VKE**: $10/month (control plane) + $48/month (2 nodes) + $20/month (storage)
- **Total**: ~$74/month

### Testing/Staging Environment (~$294/month)
- **Infracost Results**: $201.64/month (includes AWS Hyperlane validators)
- **Vultr VKE**: $10/month (control plane) + $72/month (3 nodes) + $30/month (storage)
- **Total**: ~$294/month

### Production Environment (~$308/month)
- **Infracost Results**: $201.64/month (includes AWS Hyperlane validators)
- **Vultr VKE**: $10/month (control plane) + $96/month (4 nodes) + $40/month (storage)
- **Total**: ~$308/month

## 🎯 Cost Optimization Features

### 1. Storage Lifecycle Policies
Already implemented in GCS buckets:
- **Standard** → **Nearline** after 30 days
- **Nearline** → **Coldline** after 90 days
- **Coldline** → **Archive** after 365 days

**Savings**: 60-80% on backup storage costs

### 2. Multi-Cloud Strategy
- **Vultr VKE**: Cost-effective Kubernetes clusters
- **Google Cloud**: Managed storage with lifecycle policies
- **AWS**: Available as alternative (higher cost)

**Savings**: 28-36% compared to AWS-only infrastructure

### 3. Automated Monitoring
- Prometheus metrics for resource utilization
- Grafana dashboards for cost visualization
- Alerts for unusual resource consumption

## 🔧 Usage Examples

### Basic Cost Estimation
```bash
# Get development environment costs (use your environment name)
./estimate-costs.sh your_dev_env

# Get costs in JSON format for analysis
./estimate-costs.sh your_dev_env json

# Example with IXO reference environment
./estimate-costs.sh devnet
```

### Environment Comparison
```bash
# Compare all environments
./estimate-costs.sh compare

# This generates comparison files like:
# - cost-estimates/env1-vs-env2.txt
# - cost-estimates/staging-vs-prod.txt
```

### Comprehensive Analysis
```bash
# Run complete analysis
./estimate-costs.sh all

# Generates:
# - Table format reports
# - HTML reports
# - JSON data files
# - Environment comparisons
```

## 📈 Direct Infracost Commands

### If you want to run Infracost directly:

```bash
# Basic breakdown for your development environment
infracost breakdown --path . --terraform-workspace your_dev_env

# With usage file for more accurate estimates
infracost breakdown --path . --terraform-workspace your_dev_env --usage-file infracost-usage.yml

# Multiple environments at once (requires custom infracost.yml)
infracost breakdown --config-file infracost.yml

# Generate HTML report
infracost breakdown --config-file infracost.yml --format html --out-file report.html
```

### Cost Comparison
```bash
# Compare two configurations
infracost diff --path1 config1.json --path2 config2.json

# Compare your environments
infracost diff --path1 your_dev-costs.json --path2 your_prod-costs.json
```

## ✅ Supported Services

### Fully Supported by Infracost
- ✅ **Google Cloud Storage** (buckets, lifecycle policies)
- ✅ **Google Cloud KMS** (encryption keys)
- ✅ **AWS EKS** (control plane, worker nodes)
- ✅ **AWS EBS** (storage volumes)
- ✅ **AWS S3** (object storage)
- ✅ **AWS ECS** (container services)

### Manual Estimates (Vultr)
- 📊 **Vultr VKE** (Kubernetes clusters)
- 📊 **Vultr Block Storage** (SSD/HDD storage)
- 📊 **Vultr Compute** (worker nodes)

## 🔧 Customizing for Your Organization

### Updating Environment Names

1. **Modify `infracost.yml`** to use your environment names:
   ```yaml
   projects:
     - path: .
       name: mycompany-infrastructure-dev
       terraform_workspace: mycompany_dev
       # ...
   ```

2. **Update Terraform workspaces**:
   ```bash
   terraform workspace new mycompany_dev
   terraform workspace new mycompany_staging
   terraform workspace new mycompany_prod
   ```

3. **Run cost estimates** with your environment names:
   ```bash
   ./estimate-costs.sh mycompany_dev
   ./estimate-costs.sh mycompany_staging
   ```

### Setting Up Cost Comparisons

The `compare` function will automatically detect available workspaces and compare them. To ensure proper comparisons:

1. Create consistent naming patterns (e.g., `company_dev`, `company_staging`, `company_prod`)
2. Use the same variable files across environments when possible
3. Document your environment naming in your team's README

## 🔍 Cost Monitoring

### Prometheus Metrics
Monitor actual resource usage:
```bash
# CPU usage
container_cpu_usage_seconds_total

# Memory usage
container_memory_usage_bytes

# Storage usage
kubelet_volume_stats_used_bytes
```

### Grafana Dashboards
- **Infrastructure Overview**: High-level cost and usage metrics
- **Per-Service Breakdown**: Cost allocation by service
- **Storage Analytics**: Storage usage patterns and optimization opportunities

## 🛠️ Troubleshooting

### Common Issues

1. **Infracost API Key Not Set**
   ```bash
   infracost configure set api_key YOUR_API_KEY
   ```

2. **Terraform Workspace Issues**
   ```bash
   terraform workspace list
   terraform workspace select your_env_name
   ```

3. **Missing Google Cloud Credentials**
   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS=path/to/credentials.json
   ```

### Validation
```bash
# Validate Infracost configuration
infracost breakdown --config-file infracost.yml --dry-run

# Check Terraform configuration
terraform validate

# Test authentication
infracost configure get api_key
```

## 🤝 Contributing

### Adding New Services
1. Update `infracost-usage.yml` with usage patterns
2. Update `README-vultr-cost-estimates.md` with manual pricing
3. Test with `./estimate-costs.sh your_test_env`

### Updating Pricing
1. Check latest Vultr pricing: https://www.vultr.com/pricing/
2. Update `README-vultr-cost-estimates.md`
3. Run cost comparison: `./estimate-costs.sh compare`

### For Your Organization
1. Fork this repository
2. Update environment names in `infracost.yml` and documentation
3. Modify cost estimates to match your expected usage patterns
4. Update variable files with your organization's defaults

## 📚 References

- [Infracost Documentation](https://www.infracost.io/docs/)
- [Vultr VKE Pricing](https://www.vultr.com/pricing/kubernetes/)
- [Google Cloud Storage Pricing](https://cloud.google.com/storage/pricing)
- [AWS EKS Pricing](https://aws.amazon.com/eks/pricing/)

## 🆘 Support

For questions about cost estimation:
1. Check the `README-vultr-cost-estimates.md` for detailed breakdowns
2. Run `./estimate-costs.sh all` for comprehensive analysis
3. Review generated reports in `cost-reports/` directory

## 🚨 Important Notes

- **Infracost only covers AWS/GCP resources** - Vultr costs are calculated separately
- **Actual costs may vary** based on usage patterns and optional features
- **Always run cost estimates** before making infrastructure changes
- **Monitor actual usage** to optimize costs over time
- **Customize environment names** to match your organization's conventions 