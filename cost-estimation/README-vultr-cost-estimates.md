# IXO Terra Infrastructure Cost Estimates

This document provides comprehensive cost estimates for the IXO Terra infrastructure across different cloud providers and environments.

> **For developers**: This document breaks down infrastructure costs in detail, helping you understand where the money goes and how to optimize spending.

## ⚠️ Accuracy Caveats (reviewed 2026-10-20)

**All figures below are vendor *list* prices. They have never been reconciled against an actual Vultr
invoice** — there is no `VULTR_API_KEY` in the deployment shell, so billed usage cannot be pulled
programmatically. Treat every total as a modelled estimate, not as spend.

**Node and block-storage rates were corrected on 2026-10-20.** The `vhf-3c-8gb` plan was previously
priced here at $24/month; that is the `vhf-2c-4gb` rate. `vhf-3c-8gb` lists at **$48/month**
(verified against published Vultr pricing for Amsterdam, the cluster's region — see
`modules.tf` `cluster_region`). Every node subtotal and environment total has been recomputed.
Corroboration: price aggregators list `vhf-2c-4gb` at exactly $24.00/month, confirming the old
figure was the 2c-4gb rate rather than a stale 3c-8gb price.

**The environment shapes in the tables below are stale.** They describe 2–4 node clusters with
100–400 GB of block storage. Measured live against **devnet** on **2026-10-20** (via
`modules/kubernetes_cluster/modules/vultr/kubeconfig_devnet.yaml`):

| Measured (devnet, 2026-10-20) | Value | Table below claims |
|---|---|---|
| Worker nodes (`kubectl get nodes`) | **8**, all `vhf-3c-8gb`, single pool `ixo-devnet` | 2 |
| PersistentVolumeClaims (`kubectl get pvc -A`) | **32 PVCs / 1,946 GiB** | 100 GB |
| · `vultr-block-storage` (NVMe) | 846 GiB, 18 PVCs | — |
| · `vultr-block-storage-hdd` (HDD) | 900 GiB, 12 PVCs | — |
| · `vultr-vfs-storage` (VFS) | 200 GiB, 2 PVCs | — |

Testnet and mainnet have not been measured and are very likely understated by a similar margin.

**The 8 nodes are confirmed and intentional, not drift.** `modules.tf:99` sets
`initial_node_pool_quantity = 7`, but
`modules/kubernetes_cluster/modules/vultr/main.tf:10-11` declares
`lifecycle { ignore_changes = [node_pools[0].node_quantity] }`. The 7 is therefore only the
creation-time value; the pool has since been deliberately scaled to 8 and Terraform will not
reclaim the extra node. The tables below still use the stale 2–4 node shapes.

**The VKE control plane is $0, not $10 — corrected.** Verified on 2026-10-20 against Vultr's own
documentation ([how much does VKE cost](https://docs.vultr.com/support/products/vke/how-much-does-the-vultr-kubernetes-engine-cost)),
which states VKE includes a fully-managed control plane at no additional cost and bills only for
worker nodes, load balancers and block storage. Vultr's docs draw no HA/non-HA pricing distinction.
Every environment table below now carries $0 and the totals have been reduced accordingly.

**The VFS storage rate is an estimate.** No published per-GB rate for `vultr-vfs-storage` could be
found, so the ~$12/month for devnet's 200 GiB is a placeholder, not a list price. It needs
confirmation from an invoice or from Vultr directly.

## 💰 Quick Summary

| Environment Type | Total Monthly Cost | Annual Cost | What You Get |
|------------------|-------------------|-------------|--------------|
| **Development** | **$112** | $1,347 | Basic setup for testing and development |
| **Testing/Staging** | **$355** | $4,263 | Full stack with cross-chain validators |
| **Production** | **$413** | $4,959 | Full stack with high availability |

> **Environment Naming**: These costs apply to any environment type. You can use your own naming conventions (e.g., `mycompany_dev`, `staging`, `production`) instead of the IXO-specific names referenced in our examples.

## 🔍 Why Two Cost Estimation Methods?

We use two approaches because different tools cover different services:

- **Infracost**: Automatically calculates AWS and Google Cloud costs with real-time pricing
- **Manual Calculation**: Covers Vultr VKE costs (which Infracost doesn't support yet)

## ⚡ Infrastructure Components

### 1. Kubernetes Cluster

#### 🟢 Vultr VKE (Recommended - Cost Effective)
- **VKE Control Plane**: **$0** — included free with VKE (verified against Vultr's VKE pricing doc, 2026-10-20)
- **Worker Nodes**: 2x `vhf-3c-8gb` (High Frequency 3 vCPU, 8GB RAM)
  - Cost: $48/month per node (list price, Amsterdam)
  - Total for 2 nodes: $96/month
- **Auto-scaling**: 2-4 nodes (min-max)
  - Maximum cost: $192/month (4 nodes)

> Node counts here are stale — devnet actually runs **8** nodes as of 2026-10-20 (= **$384/month**
> at $48/node), confirmed live and intentional. See the caveats section above.

#### 🔴 AWS EKS (Alternative - More Expensive)
- **EKS Control Plane**: $72/month per cluster (Vultr VKE charges $0 for this)
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

Published Vultr block-storage rates:

| Tier | Per TB/month | Per GiB/month |
|---|---|---|
| **HDD** (bulk) | $25 | $0.025 |
| **NVMe** (high performance) | $100 | $0.10 |

Illustrative volumes, priced at the **NVMe** rate:
- **PostgreSQL Storage**: 200GB NVMe = $20/month
- **Matrix Media Storage**: 500GB NVMe = $50/month (a good HDD candidate: $12.50/month)
- **Loki Logs Storage**: 300GB NVMe = $30/month (a good HDD candidate: $7.50/month)
- **Application Storage**: 100GB NVMe = $10/month

> These volumes are stale. Devnet alone held **1,946 GiB** across 32 PVCs on 2026-10-20
> (846 GiB NVMe = $84.60, 900 GiB HDD = $22.50, 200 GiB VFS = ~$12 — **estimated**, no published
> VFS rate). See the caveats section above.

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

### Development Environment ($112/month)
*Example: your_dev, company_dev, devnet*

| Service | Monthly Cost | Notes |
|---------|-------------|--------|
| **Vultr VKE Control Plane** | $0 | Included free with VKE |
| **Vultr Worker Nodes** | $96 | 2x vhf-3c-8gb @ $48 |
| **Vultr Block Storage** | $10 | 100GB NVMe @ $0.10/GiB |
| **Google Cloud KMS** | $6.24 | 4 encryption keys |
| **Total Development** | **$112.24** | Perfect for testing and development |

> Stale shape. Real devnet, measured 2026-10-20: 8 nodes × $48 = $384.00, + $84.60 NVMe
> (846 GiB), + $22.50 HDD (900 GiB), + ~$12 VFS (200 GiB, **estimated**), + $0 control plane,
> + $6.24 GCP KMS = **≈ $509/month**, not $112. See the caveats section above.

### Testing/Staging Environment ($355/month)
*Example: your_staging, company_test, testnet*

| Service | Monthly Cost | Notes |
|---------|-------------|--------|
| **Vultr VKE Control Plane** | $0 | Included free with VKE |
| **Vultr Worker Nodes** | $144 | 3x vhf-3c-8gb @ $48 |
| **Vultr Block Storage** | $30 | 300GB NVMe @ $0.10/GiB |
| **Google Cloud KMS** | $6.24 | 4 encryption keys |
| **AWS Hyperlane Validators** | $175 | Cross-chain bridge services |
| **Total Testing** | **$355.24** | Full stack for staging |

> Shape unverified and probably understated — **testnet was not measured**. Devnet's real shape was
> 4x the nodes and ~19x the storage this table assumes. A kubeconfig exists at
> `modules/kubernetes_cluster/modules/vultr/kubeconfig_testnet.yaml`; measuring testnet is an open
> item.

### Production Environment ($413/month)
*Example: your_prod, company_prod, mainnet*

| Service | Monthly Cost | Notes |
|---------|-------------|--------|
| **Vultr VKE Control Plane** | $0 | Included free with VKE |
| **Vultr Worker Nodes** | $192 | 4x vhf-3c-8gb @ $48 |
| **Vultr Block Storage** | $40 | 400GB NVMe @ $0.10/GiB |
| **Google Cloud KMS** | $6.24 | 4 encryption keys |
| **AWS Hyperlane Validators** | $175 | Cross-chain bridge services |
| **Total Production** | **$413.24** | Full stack with high availability |

> Shape unverified and probably understated — **mainnet was not measured, and must not be queried
> without sign-off**. The 400GB total this table implies is already implausible: mainnet's Matrix
> media PVC alone was recently raised to 150Gi, before any other volume is counted. A kubeconfig
> exists at `modules/kubernetes_cluster/modules/vultr/kubeconfig_mainnet.yaml`; measuring mainnet is
> an open item.

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

**Savings vs AWS-only**: ~39% ($88/month per environment, at the corrected $48 node rate and $0
control plane) — but this is AWS **on-demand** at the stale 2-node shape. On Spot, and at devnet's
real measured size, AWS is *cheaper*; see the caveat under the Vultr vs AWS table below.

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
- **Use bulk storage**: For logs and backups (HDD $0.025/GiB vs NVMe $0.10/GiB)

## 🏆 Vultr vs AWS Cost Comparison

| Component | Vultr VKE | AWS EKS | Monthly Savings |
|-----------|-----------|---------|----------------|
| **Control Plane** | $0 | $72 | $72 |
| **2 Worker Nodes** | $96 | $120 | $24 |
| **Storage (400GB)** | $40 | $32 | -$8 |
| **Total** | $136 | $224 | **$88** |

**Annual Savings with Vultr**: $1,056 per environment

> ⚠️ **This comparison does not hold at real scale, and its AWS figures are unverified.** It
> prices AWS **on-demand** at the stale 2-node shape. AWS EKS on **Spot** instances is roughly
> 47–56% cheaper per node, which reverses the conclusion once devnet's actual size is used: the
> AWS devnet rebuild costing in `~/Documents/ixo-devops/projects/aws-devnet-rebuild.md` §3 puts
> EKS-on-Spot at ≈$443/month against Vultr's ≈$509/month for the same measured workload — i.e.
> AWS comes out *cheaper*, not 39% dearer. The AWS numbers in the table above have also never been
> verified ($120 for 2 worker nodes implies $60/node, which matches no instance type we have
> priced). Treat the table as illustrative only and use the rebuild spec for the real comparison.

## 📈 Scaling Costs

### How Costs Scale with Usage
- **More users**: Requires more worker nodes (+$48/month per `vhf-3c-8gb` node)
- **More data**: Requires more storage (+$0.10/GiB/month NVMe, +$0.025/GiB/month HDD)
- **More environments**: Linear scaling (+$112/month per dev environment)

### Cost per User (Rough Estimates)
- **Development**: $112/month ÷ 5 developers = $22/developer/month
- **Production**: $413/month ÷ 1000 users = $0.41/user/month

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
| **Development** | $112 | $1,347 | $4,041 |
| **Testing/Staging** | $355 | $4,263 | $12,789 |
| **Production** | $413 | $4,959 | $14,877 |
| **All Environments** | $880 | $10,569 | $31,707 |

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
A: Storage scales linearly at $0.10/GiB/month for Vultr NVMe block storage, or $0.025/GiB/month for HDD.

**Q: How accurate are these estimates?**
A: The unit *rates* are current list prices (checked 2026-10-20). The *quantities* are stale — see
the caveats at the top of this document — and no total here has ever been checked against a real
Vultr invoice, so actual spend can be several times these figures.

**Q: Do I need to use the same environment names as IXO?**
A: No! Use any names that make sense for your organization. The cost estimates apply to any environment type.

### Getting Help
1. **Cost estimates**: Run `./estimate-costs.sh your_env_name` (from repo root)
2. **Detailed analysis**: Check generated reports in `cost-reports/`
3. **Optimization**: Review Grafana dashboards for usage patterns
