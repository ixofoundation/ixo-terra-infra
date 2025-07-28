# Matrix LiveKit JWT Service Helm Chart

This Helm chart deploys the LiveKit JWT Token Management Service for Matrix, which enables Element Call to work with LiveKit backends by exchanging Matrix OpenID tokens for LiveKit JWT tokens.

## Overview

The LiveKit JWT service is a component that:
- Accepts Matrix OpenID tokens from Element Call clients
- Validates these tokens against Matrix homeservers
- Issues LiveKit JWT tokens for authenticated users to access LiveKit SFU

This is part of the [MSC4195: MatrixRTC using LiveKit backend](https://github.com/matrix-org/matrix-spec-proposals/pull/4195) specification.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- A running LiveKit SFU instance
- Matrix homeserver with OpenID support

## Installing the Chart

### 1. Add the repository (if published)

```bash
helm repo add matrix-livekit https://your-repo.com/charts
helm repo update
```

### 2. Install with minimal configuration

```bash
helm install my-livekit-jwt matrix-livekit/matrix-livekit \
  --set livekit.url="wss://livekit.example.com" \
  --set livekit.key="devkey" \
  --set livekit.secret="devsecret" \
  --set secrets.create=true
```

### 3. Install with custom values file

Create a `values.yaml` file:

```yaml
livekit:
  url: "wss://livekit.example.com"
  key: "your-livekit-api-key"
  secret: "your-livekit-secret"

secrets:
  create: true

ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  hosts:
    - host: livekit-jwt.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: livekit-jwt-tls
      hosts:
        - livekit-jwt.example.com

resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 50m
    memory: 64Mi
```

Then install:

```bash
helm install my-livekit-jwt matrix-livekit/matrix-livekit -f values.yaml
```

## Configuration

### Required Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `livekit.url` | WebSocket URL of your LiveKit SFU | `""` (required) |
| `livekit.key` or equivalent | LiveKit API key | `""` (required) |
| `livekit.secret` or equivalent | LiveKit API secret | `""` (required) |

### Authentication Methods

Choose one of these methods to provide LiveKit credentials:

#### Method 1: Direct values (recommended for testing only)
```yaml
livekit:
  key: "devkey"
  secret: "devsecret"
secrets:
  create: true
```

#### Method 2: Existing secret
```yaml
secrets:
  create: false
  name: "my-existing-secret"
```

#### Method 3: File-based credentials
```yaml
livekit:
  keyFromFile: "/path/to/key/file"
  secretFromFile: "/path/to/secret/file"
volumes:
  - name: credentials
    secret:
      secretName: livekit-credential-files
volumeMounts:
  - name: credentials
    mountPath: /path/to
    readOnly: true
```

#### Method 4: Key file format
```yaml
livekit:
  keyFile: "/path/to/keyfile"
secrets:
  create: true
  data:
    livekit-keyfile: "apikey:secret"
```

### Ingress Configuration

To expose the service externally:

```yaml
ingress:
  enabled: true
  className: "nginx"  # or your ingress class
  annotations:
    kubernetes.io/tls-acme: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  hosts:
    - host: livekit-jwt.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: livekit-jwt-tls
      hosts:
        - livekit-jwt.example.com
```

### High Availability

For production deployments:

```yaml
replicaCount: 3

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80

podDisruptionBudget:
  enabled: true
  minAvailable: 1

affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app.kubernetes.io/name
            operator: In
            values:
            - matrix-livekit
        topologyKey: kubernetes.io/hostname
```

### Security

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  capabilities:
    drop:
    - ALL

podSecurityContext:
  fsGroup: 2000

networkPolicy:
  enabled: true
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
      ports:
        - protocol: TCP
          port: 8080
  egress:
    - to: []  # Allow Matrix homeserver access
      ports:
        - protocol: TCP
          port: 443
        - protocol: TCP
          port: 8448
```

## Matrix Integration

### Well-Known Configuration

Add this to your Matrix homeserver's `/.well-known/matrix/client` response:

```json
{
  "m.homeserver": {
    "base_url": "https://matrix.example.com"
  },
  "org.matrix.msc4143.rtc_foci": [{
    "type": "livekit",
    "livekit_service_url": "https://livekit-jwt.example.com"
  }]
}
```

### Element Call Configuration

Configure Element Call to use your Matrix homeserver with the well-known configuration above.

## Monitoring

### Health Checks

The service provides a health endpoint at `/healthz`:

```bash
curl https://livekit-jwt.example.com/healthz
```

### Metrics

Currently, the service doesn't expose Prometheus metrics. Consider adding a sidecar or using ingress-level monitoring.

## Troubleshooting

### Common Issues

1. **Service not starting**: Check that all required environment variables are set
   ```bash
   kubectl logs deployment/my-livekit-jwt
   ```

2. **Authentication failures**: Verify LiveKit credentials and connectivity to LiveKit SFU
   ```bash
   kubectl exec deployment/my-livekit-jwt -- env | grep LIVEKIT
   ```

3. **Matrix homeserver connectivity**: Check network policies and DNS resolution
   ```bash
   kubectl exec deployment/my-livekit-jwt -- nslookup matrix.example.com
   ```

### Debug Mode

Enable TLS verification skip for testing (DO NOT use in production):

```yaml
livekit:
  insecureSkipVerifyTLS: true
```

## Uninstalling

```bash
helm uninstall my-livekit-jwt
```

## Development

### Testing the Chart

```bash
# Lint the chart
helm lint chart/matrix_livekit

# Template the chart
helm template my-livekit-jwt chart/matrix_livekit

# Test the deployment
helm test my-livekit-jwt
```

### Values Schema

See `values.yaml` for all available configuration options.

## Contributing

1. Fork the repository
2. Create your feature branch
3. Test your changes
4. Submit a pull request

## License

This chart is licensed under the same license as the LiveKit JWT Service project. 