# DevOps Requirements for LiveKit JWT Service

## Summary
This service acts as a bridge between Matrix homeservers and LiveKit SFU, exchanging Matrix OpenID tokens for LiveKit JWT tokens to enable Element Call video conferencing.

## Required Infrastructure Dependencies

### 1. LiveKit SFU Instance
- **Status**: EXTERNAL DEPENDENCY - Must be deployed separately
- **Purpose**: Selective Forwarding Unit for video/audio processing
- **Repository**: https://github.com/livekit/livekit
- **Configuration needed**: 
  - WebSocket endpoint URL (e.g., `wss://livekit.example.com`)
  - API key and secret for JWT generation

### 2. Matrix Homeserver
- **Status**: EXTERNAL DEPENDENCY - Must exist and be reachable
- **Purpose**: Validates OpenID tokens from clients
- **Requirements**:
  - Must support OpenID endpoint (`/_matrix/federation/v1/openid/userinfo`)
  - Must be accessible from Kubernetes cluster
  - Standard ports: 443 (HTTPS) or 8448 (Matrix federation)

### 3. Kubernetes Cluster
- **Version**: 1.19+ (for networking.k8s.io/v1 Ingress support)
- **Resources**: Minimal - service is lightweight
- **RBAC**: Standard service account permissions

## Required Configuration Inputs

### Mandatory Environment Variables
```bash
# LiveKit SFU connection
LIVEKIT_URL="wss://livekit.example.com"

# Authentication (choose one method):
# Method 1: Direct credentials
LIVEKIT_KEY="your-api-key"
LIVEKIT_SECRET="your-secret-key"

# Method 2: File-based (for secret mounting)
LIVEKIT_KEY_FROM_FILE="/path/to/key"
LIVEKIT_SECRET_FROM_FILE="/path/to/secret"

# Method 3: Combined key file
LIVEKIT_KEY_FILE="/path/to/keyfile"  # Format: "apikey:secret"
```

### Optional Configuration
```bash
LIVEKIT_JWT_PORT="8080"  # Default port
LIVEKIT_INSECURE_SKIP_VERIFY_TLS="YES_I_KNOW_WHAT_I_AM_DOING"  # Testing only
```

## Network Requirements

### Ingress
- **Purpose**: Expose service to Element Call clients
- **Port**: 80/443 (HTTP/HTTPS)
- **Paths**: `/sfu/get` (main API), `/healthz` (health check)
- **TLS**: Required for production (Matrix spec requires HTTPS)

### Egress
- **Matrix Homeserver**: 443/8448 (HTTPS/Matrix federation)
- **DNS**: 53 (for homeserver discovery via well-known)
- **LiveKit SFU**: Varies (typically 443 for WSS)

## Security Considerations

### Secrets Management
- LiveKit credentials must be stored as Kubernetes secrets
- Never expose credentials in logs or environment variables directly
- Consider using external secret management (Vault, AWS Secrets Manager, etc.)

### Network Policies
- Restrict ingress to necessary sources (ingress controller, load balancer)
- Allow egress to Matrix homeservers and LiveKit SFU only
- Block unnecessary inter-pod communication

### Pod Security
- Run as non-root user (UID 1000)
- Drop all capabilities
- Use read-only root filesystem where possible
- Apply security contexts

## Monitoring & Observability

### Health Checks
- **Endpoint**: `GET /healthz`
- **Expected Response**: HTTP 200 OK
- **Purpose**: Kubernetes liveness/readiness probes

### Logging
- Application logs to stdout/stderr (captured by Kubernetes)
- Structured logging with request IDs for tracing
- Log level configurable (currently minimal)

### Metrics
- **Current State**: No Prometheus metrics exposed
- **Recommendation**: Add metrics for request count, error rates, response times
- **Alternative**: Use ingress-level metrics or service mesh observability

## High Availability

### Horizontal Scaling
- **Stateless**: Service can be horizontally scaled
- **Load Balancing**: Standard Kubernetes service load balancing
- **Session Affinity**: Not required
- **Recommended**: 2+ replicas for production

### Fault Tolerance
- **Dependencies**: Graceful handling of Matrix homeserver and LiveKit SFU outages
- **Retry Logic**: Built-in for Matrix homeserver communication
- **Circuit Breaker**: Not implemented (consider adding for production)

## Resource Requirements

### Compute
```yaml
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 100m
    memory: 128Mi
```

### Storage
- **Persistent Storage**: Not required (stateless service)
- **Temporary**: Standard container filesystem sufficient

## Matrix Integration Requirements

### Well-Known Configuration
Matrix homeserver must serve this in `/.well-known/matrix/client`:
```json
{
  "org.matrix.msc4143.rtc_foci": [{
    "type": "livekit",
    "livekit_service_url": "https://livekit-jwt.example.com"
  }]
}
```

### DNS Requirements
- `livekit-jwt.example.com` → Service endpoint (via ingress)
- Matrix homeserver must be resolvable from cluster
- LiveKit SFU must be resolvable from cluster

## Deployment Checklist

- [ ] LiveKit SFU is deployed and accessible
- [ ] Matrix homeserver is running and accessible
- [ ] DNS records configured for service endpoint
- [ ] TLS certificates available for HTTPS
- [ ] LiveKit API credentials obtained
- [ ] Kubernetes namespace created
- [ ] Secret created with LiveKit credentials
- [ ] Ingress controller available
- [ ] Resource quotas sufficient
- [ ] Network policies configured (if required)
- [ ] Monitoring configured
- [ ] Matrix well-known updated
- [ ] Element Call configured to use Matrix homeserver

## Testing Validation

### Health Check
```bash
curl -f https://livekit-jwt.example.com/healthz
```

### End-to-End Test
1. Deploy Element Call
2. Create Matrix room with video call
3. Verify JWT token exchange works
4. Verify video/audio connection to LiveKit SFU

### Load Testing
- Test token exchange rate limits
- Verify concurrent user handling
- Monitor resource usage under load 