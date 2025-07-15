# IXO Terra Infrastructure Cost Estimates

This document provides comprehensive cost estimates for the IXO Terra infrastructure across different cloud providers and environments.

> **For developers**: This document breaks down infrastructure costs in detail, helping you understand where the money goes and how to optimize spending. All costs are based on 2025 pricing research.

## 💰 Quick Summary

| Environment Type | Total Monthly Cost | Annual Cost | What You Get |
|------------------|-------------------|-------------|--------------|
| **Development** | **$74** | $888 | Basic setup for testing and development |
| **Testing/Staging** | **$294** | $3,528 | Full stack with cross-chain validators |
| **Production** | **$308** | $3,696 | Full stack with high availability |

> **Environment Naming**: These costs apply to any environment type. You can use your own naming conventions (e.g., `mycompany_dev`, `staging`, `production`) instead of the IXO-specific names referenced in our examples.

## 🔍 Why Two Cost Estimation Methods?

We use two approaches because different tools cover different services:

- **Infracost**: Automatically calculates AWS and Google Cloud costs with real-time pricing
- **Manual Calculation**: Covers Vultr VKE costs (which Infracost doesn't support yet)

## ⚡ Infrastructure Components

### 1. Kubernetes Cluster

#### 🟢 Vultr VKE (Recommended - Cost Effective)
- **VKE Control Plane**: $10/month per cluster
- **Worker Nodes**: 2x `vhf-3c-8gb` (High Frequency 3 vCPU, 8GB RAM)
  - Cost: ~$24/month per node
  - Total for 2 nodes: $48/month
- **Auto-scaling**: 2-4 nodes (min-max)
  - Maximum cost: $96/month (4 nodes)

#### 🔴 AWS EKS (Alternative - More Expensive)
- **EKS Control Plane**: $72/month per cluster (7x more expensive!)
- **EC2 Worker Nodes**: 2x `t3.medium` (2 vCPU, 4GB RAM)
  - Cost: ~$30/month per node
  - Total for 2 nodes: $60/month
- **EBS Storage**: 800GB per node
  - Cost: ~$80/month per node
  - Total for 2 nodes: $160/month

### 2. Storage Solutions

#### 🟢 Google Cloud Storage (Recommended - with Smart Lifecycle)
- **PostgreSQL Backups**: 500GB
  - Standard storage: $13/month
  - Nearline (60+ days): $5/month
  - Coldline (90+ days): $2/month
  - Operations: $0.50/month
- **Matrix Backups**: 1TB
  - Standard storage: $26/month
  - Nearline (60+ days): $10/month
  - Coldline (90+ days): $4/month
  - Operations: $0.25/month
- **Loki Logs**: 2TB
  - Standard storage: $52/month
  - Nearline (60+ days): $20/month
  - Coldline (90+ days): $8/month
  - Operations: $0.75/month

#### Vultr Block Storage (On-Cluster)
- **PostgreSQL Storage**: 200GB SSD = $20/month
- **Matrix Media Storage**: 500GB SSD = $50/month
- **Loki Logs Storage**: 300GB SSD = $30/month
- **Application Storage**: 100GB SSD = $10/month

### 3. Security & Encryption

#### Google Cloud KMS (from Infracost)
- **4 KMS Keys**: $1.56/month each
- **Total**: $6.24/month
- **What it does**: Encrypts your data at rest (databases, backups, secrets)

#### HashiCorp Vault
- **Self-hosted on Kubernetes**: Included in cluster costs
- **What it does**: Manages application secrets, API keys, passwords

### 4. Monitoring & Observability

#### Prometheus & Grafana
- **Storage**: Included in cluster storage
- **Compute**: Included in cluster compute
- **What it does**: Metrics collection, alerting, dashboards

#### Loki (Log Aggregation)
- **Storage**: See storage section above
- **Compute**: Included in cluster compute
- **What it does**: Centralized logging from all applications

### 5. Communication (Matrix Homeserver)

#### Synapse Server
- **Compute**: Included in cluster compute
- **PostgreSQL Database**: Included in cluster compute
- **Media Storage**: See storage section above
- **What it does**: Self-hosted chat/messaging server

## 📊 Detailed Cost Breakdown by Environment Type

### Development Environment ($74/month)
*Example: your_dev, company_dev, devnet*

| Service | Monthly Cost | Notes |
|---------|-------------|--------|
| **Vultr VKE Control Plane** | $10 | Kubernetes management |
| **Vultr Worker Nodes** | $48 | 2x vhf-3c-8gb nodes |
| **Vultr Block Storage** | $10 | 100GB for apps |
| **Google Cloud KMS** | $6.24 | 4 encryption keys |
| **Total Development** | **$74.24** | Perfect for testing and development |

### Testing/Staging Environment ($294/month)
*Example: your_staging, company_test, testnet*

| Service | Monthly Cost | Notes |
|---------|-------------|--------|
| **Vultr VKE Control Plane** | $10 | Kubernetes management |
| **Vultr Worker Nodes** | $72 | 3x vhf-3c-8gb nodes |
| **Vultr Block Storage** | $30 | 300GB for apps |
| **Google Cloud KMS** | $6.24 | 4 encryption keys |
| **AWS Hyperlane Validators** | $175 | Cross-chain bridge services |
| **Total Testing** | **$293.24** | Full stack for staging |

### Production Environment ($308/month)
*Example: your_prod, company_prod, mainnet*

| Service | Monthly Cost | Notes |
|---------|-------------|--------|
| **Vultr VKE Control Plane** | $10 | Kubernetes management |
| **Vultr Worker Nodes** | $96 | 4x vhf-3c-8gb nodes |
| **Vultr Block Storage** | $40 | 400GB for apps |
| **Google Cloud KMS** | $6.24 | 4 encryption keys |
| **AWS Hyperlane Validators** | $175 | Cross-chain bridge services |
| **Total Production** | **$327.24** | Full stack with high availability |

## 💡 Cost Optimization Strategies

### 1. Smart Storage Lifecycle (Already Implemented!)
We automatically move data to cheaper storage:
- **Standard** → **Nearline** after 30 days (-50% cost)
- **Nearline** → **Coldline** after 90 days (-80% cost)  
- **Coldline** → **Archive** after 365 days (-90% cost)

**Annual Savings**: $2,000-3,000 on backup storage

### 2. Multi-Cloud Strategy (Current Approach)
- **Vultr VKE**: Cost-effective Kubernetes clusters
- **Google Cloud**: Managed storage with lifecycle policies
- **AWS**: Only for specific services (Hyperlane validators)

**Savings vs AWS-only**: 28-36% ($150-200/month)

### 3. Development Environment Optimization
Disable expensive services in development:
- ❌ Matrix server (chat) - Save $50/month
- ❌ Loki logging - Save $30/month  
- ❌ Cross-chain validators - Save $175/month
- ✅ Keep core monitoring and databases

**Development Savings**: $255/month vs full stack

### 4. Right-sizing Recommendations
Monitor actual usage and adjust:
- **Start small**: Use minimum node counts
- **Scale up**: Only when needed based on metrics
- **Use bulk storage**: For logs and backups ($0.04/GB vs $0.10/GB)

## 🏆 Vultr vs AWS Cost Comparison

| Component | Vultr VKE | AWS EKS | Monthly Savings |
|-----------|-----------|---------|----------------|
| **Control Plane** | $10 | $72 | $62 |
| **2 Worker Nodes** | $48 | $120 | $72 |
| **Storage (400GB)** | $40 | $32 | -$8 |
| **Total** | $98 | $224 | **$126** |

**Annual Savings with Vultr**: $1,512 per environment

## 📈 Scaling Costs

### How Costs Scale with Usage
- **More users**: Requires more worker nodes (+$24/month per node)
- **More data**: Requires more storage (+$0.10/GB/month)
- **More environments**: Linear scaling (+$74/month per dev environment)

### Cost per User (Rough Estimates)
- **Development**: $74/month ÷ 5 developers = $15/developer/month
- **Production**: $308/month ÷ 1000 users = $0.31/user/month

## 🚨 Hidden Costs to Watch

### Potential Additional Costs
- **Network Transfer**: $0.01-0.02/GB (usually minimal)
- **Domain Names**: $10-15/year per domain
- **SSL Certificates**: $0 (automated with Let's Encrypt)
- **Support**: Free (community support) or $50+/month (commercial)

### Cost Spikes to Monitor
- **Data transfer spikes**: Monitor Grafana dashboards
- **Storage growth**: Set up alerts at 80% capacity
- **Compute usage**: Scale down nodes during low-usage periods

## 📋 Annual Budget Planning

| Environment Type | Monthly | Annual | 3-Year Total |
|------------------|---------|--------|-------------|
| **Development** | $74 | $888 | $2,664 |
| **Testing/Staging** | $294 | $3,528 | $10,584 |
| **Production** | $308 | $3,696 | $11,088 |
| **All Environments** | $676 | $8,112 | $24,336 |

## 🔧 Cost Monitoring Tools

### Built-in Monitoring
- **Prometheus**: Resource usage metrics
- **Grafana**: Cost visualization dashboards  
- **Alerts**: Unusual spending notifications

### Monthly Cost Review Checklist
- [ ] Check Vultr billing dashboard
- [ ] Review Google Cloud billing
- [ ] Check AWS costs (if using Hyperlane)
- [ ] Review storage usage trends
- [ ] Check for idle resources

## 📚 References & Pricing Sources

- [Vultr VKE Pricing (2025)](https://www.vultr.com/pricing/kubernetes/)
- [Google Cloud Storage Pricing](https://cloud.google.com/storage/pricing)
- [AWS EKS Pricing](https://aws.amazon.com/eks/pricing/)
- [Vultr Block Storage Pricing](https://www.vultr.com/pricing/block-storage/)

## 🆘 Cost Questions & Support

### Common Questions

**Q: Why is Vultr cheaper than AWS?**
A: Vultr focuses on cost-effective cloud services with simpler pricing. AWS has more features but higher costs.

**Q: Can I reduce costs further?**
A: Yes! Disable optional services in development, use smaller node sizes, or implement spot instances.

**Q: What if I need more storage?**
A: Storage scales linearly at $0.10/GB/month for Vultr block storage.

**Q: How accurate are these estimates?**
A: Very accurate for base infrastructure. Actual costs may vary ±10% based on usage patterns.

**Q: Do I need to use the same environment names as IXO?**
A: No! Use any names that make sense for your organization. The cost estimates apply to any environment type.

### Getting Help
1. **Cost estimates**: Run `./estimate-costs.sh your_env_name`
2. **Detailed analysis**: Check generated reports in `cost-reports/`
3. **Optimization**: Review Grafana dashboards for usage patterns 