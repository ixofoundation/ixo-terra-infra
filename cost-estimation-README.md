# IXO Terra Infrastructure Cost Estimation

This repository includes comprehensive cost estimation tools for the IXO Terra infrastructure using Infracost and manual calculations for Vultr services.

## Quick Start

### Prerequisites

1. **Infracost CLI** (already installed)
2. **Terraform** (already configured)
3. **Google Cloud credentials** (already configured)
4. **Infracost API key** (already configured)

### Running Cost Estimates

```bash
# Make the script executable
chmod +x estimate-costs.sh

# Estimate costs for a specific environment
./estimate-costs.sh devnet
./estimate-costs.sh testnet
./estimate-costs.sh mainnet

# Compare costs between environments
./estimate-costs.sh compare

# Generate comprehensive reports
./estimate-costs.sh report

# Run complete cost analysis
./estimate-costs.sh all
```

## Cost Estimation Files

### 1. `infracost.yml`
Main configuration file that defines:
- Multiple environments (devnet, testnet, mainnet)
- Terraform workspaces
- Variable files
- Output formats

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

### 4. `vultr-cost-estimates.md`
Comprehensive cost breakdown including:
- Vultr VKE pricing (not covered by Infracost)
- GCS storage costs with lifecycle policies
- Environment-specific totals
- AWS cost comparisons

## Current Cost Estimates

Based on the latest analysis:

| Environment | Monthly Cost | Annual Cost |
|-------------|-------------|-------------|
| **DevNet** | $214.24 | $2,571 |
| **TestNet** | $298.24 | $3,579 |
| **MainNet** | $432.24 | $5,187 |

### Cost Breakdown

#### Infrastructure Components (DevNet)
- Vultr VKE Control Plane: $10/month
- Vultr Worker Nodes (2x): $48/month
- Vultr Block Storage: $110/month
- Google Cloud KMS: $6.24/month
- GCS Backups: $35/month
- Network Transfer: $5/month

## Cost Optimization Features

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

## CI/CD Integration

### GitHub Actions Workflow
File: `.github/workflows/infracost.yml`

Features:
- **Automatic cost estimation** on pull requests
- **Cost diff comments** showing changes
- **Threshold checking** (blocks PRs with high cost increases)
- **Environment-specific estimates** for all environments
- **Artifact uploads** for detailed reports

### Required Secrets
Add these to your GitHub repository secrets:
- `INFRACOST_API_KEY`: Your Infracost API key
- `GCP_SA_KEY`: Google Cloud service account key

## Usage Examples

### Basic Cost Estimation
```bash
# Get DevNet costs
./estimate-costs.sh devnet

# Get costs in JSON format
./estimate-costs.sh devnet json
```

### Environment Comparison
```bash
# Compare all environments
./estimate-costs.sh compare

# This generates:
# - cost-estimates/devnet-vs-testnet.txt
# - cost-estimates/testnet-vs-mainnet.txt
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

## Infracost Commands

### Direct Infracost Usage
```bash
# Basic breakdown
infracost breakdown --path . --terraform-workspace devnet

# With usage file
infracost breakdown --path . --terraform-workspace devnet --usage-file infracost-usage.yml

# Multiple environments
infracost breakdown --config-file infracost.yml

# Generate HTML report
infracost breakdown --config-file infracost.yml --format html --out-file report.html
```

### Cost Comparison
```bash
# Compare two configurations
infracost diff --path1 config1.json --path2 config2.json

# Compare environments
infracost diff --path1 devnet-costs.json --path2 mainnet-costs.json
```

## Supported Services

### Fully Supported by Infracost
- ✅ **Google Cloud Storage** (buckets, lifecycle policies)
- ✅ **Google Cloud KMS** (encryption keys)
- ✅ **AWS EKS** (control plane, worker nodes)
- ✅ **AWS EBS** (storage volumes)
- ✅ **AWS S3** (object storage)

### Manual Estimates (Vultr)
- 📊 **Vultr VKE** (Kubernetes clusters)
- 📊 **Vultr Block Storage** (SSD/HDD storage)
- 📊 **Vultr Compute** (worker nodes)

## Cost Monitoring

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

## Troubleshooting

### Common Issues

1. **Infracost API Key Not Set**
   ```bash
   infracost configure set api_key YOUR_API_KEY
   ```

2. **Terraform Workspace Issues**
   ```bash
   terraform workspace list
   terraform workspace select devnet
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

## Contributing

### Adding New Services
1. Update `infracost-usage.yml` with usage patterns
2. Update `vultr-cost-estimates.md` with manual pricing
3. Test with `./estimate-costs.sh devnet`

### Updating Pricing
1. Check latest Vultr pricing: https://www.vultr.com/pricing/
2. Update `vultr-cost-estimates.md`
3. Run cost comparison: `./estimate-costs.sh compare`

## References

- [Infracost Documentation](https://www.infracost.io/docs/)
- [Vultr VKE Pricing](https://www.vultr.com/pricing/kubernetes/)
- [Google Cloud Storage Pricing](https://cloud.google.com/storage/pricing)
- [AWS EKS Pricing](https://aws.amazon.com/eks/pricing/)

## Support

For questions about cost estimation:
1. Check the `vultr-cost-estimates.md` for detailed breakdowns
2. Run `./estimate-costs.sh all` for comprehensive analysis
3. Review generated reports in `cost-reports/` directory 