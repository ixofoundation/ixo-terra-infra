# Targeted plan/apply with your own identities

This is how to run `terraform plan` / `apply` against one module (for example `module.matrix`) using only your own logins:

- AWS SSO,
- a Vault OIDC token,
- gcloud application-default credentials.

You do not need `credentials.json`, the shared Vault `terraform` password or any OIDC client secret.

## One-time setup

### AWS SSO profiles

The kubeconfig and the state backend hardcode these profile names, so name your profiles exactly like this:

| Profile      | Account      | Used for                          |
|--------------|--------------|-----------------------------------|
| `ixo-dev`    | 896358490078 | devnet cluster                    |
| `ixo-test`   | 536202635008 | testnet cluster                   |
| `ixo-prod`   | 361082683495 | mainnet cluster                   |
| `ixo-devops` | 665549645984 | Terraform state (S3 backend)      |

Use the `AWSAdministratorAccess` permission set. It is the role the EKS access entries trust. Ask the infra lead for the SSO start URL.

```bash
aws sso login --profile ixo-dev
```

### Vault

Log in with GitHub through OIDC, once per environment. You need to be in the `<env>-devsecops` GitHub team.

```bash
VAULT_ADDR=https://vault.devnet.ixo.earth vault login -method=oidc role=admin
```

`~/.vault-token` holds one token only, so log in again when you switch environment.

### GCP

```bash
gcloud auth application-default login
```

Your Google account needs read access to the environment's GCS buckets in the GCP project. Project Viewer is enough for `module.matrix`.

### Terraform

Use Terraform 1.15.8 (`tfenv use 1.15.8`). The state is written by this version.

### Init

Once per clone, after `aws sso login --profile ixo-devops`:

```bash
terraform init
```

## Running

Example for devnet. Swap the profile, Vault host, workspace and var-file for other environments.

```bash
export AWS_PROFILE=ixo-dev
export VAULT_ADDR=https://vault.devnet.ixo.earth
export TF_VAR_vault_userpass_login=false
terraform workspace select devnet
terraform plan  -var-file=terraform-aws-devnet-dev.tfvars -target=module.matrix
terraform apply -var-file=terraform-aws-devnet-dev.tfvars -target=module.matrix
```

`TF_VAR_vault_userpass_login=false` makes the Vault provider use your own token instead of the shared `terraform` user. The AWS provider refuses to run against the wrong account, and `required_version` pins Terraform to 1.15.8.

| Profile    | Vault host                  | Workspace | Var-file                             |
|------------|-----------------------------|-----------|--------------------------------------|
| `ixo-dev`  | `vault.devnet.ixo.earth`    | `devnet`  | `terraform-aws-devnet-dev.tfvars`    |
| `ixo-test` | `vault.testnet.ixo.earth`   | `testnet` | `terraform-aws-testnet-test.tfvars`  |
| `ixo-prod` | `vault.mainnet.ixo.earth`   | `mainnet` | `terraform-aws-mainnet-main.tfvars`  |

## Rules

- **Always use `-target`.** Every workspace carries unrelated drift, so a full plan is never safe.
- **Never target these modules:**
  - `gcp_kms_*`: destroying a key version makes Vault unrecoverable.
  - `cloudflare_workers_db_tunnel` is cutover-only.
- **Targets that depend on `module.argocd`** (most modules with `depends_on = [module.argocd]`, including `module.postgres-operator`) pull in the ArgoCD helm release. That release needs the ArgoCD GitHub OIDC secret, which you don't have. Without it the plan stops at a precondition rather than blanking the SSO client. Ask the infra lead to run those targets.
- **Targets that need `credentials.json`:** `module.postgres-operator` refuses to plan without the file, rather than blank the pgBackRest key.
- **Fresh cluster:** apply `module.argocd` before `module.matrix`. Matrix no longer depends on the argocd release.
