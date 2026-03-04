# Manual Kubernetes templates

One-off or manually applied Kubernetes YAML manifests that are not managed by Terraform/Helm/Argo CD.

- **filebrowser-pod.yaml** – Filebrowser pod for devops file access (replace `${ORG}` with your org name before applying).

Apply from repo root, e.g.:

```bash
kubectl apply -f templates/filebrowser-pod.yaml
```
