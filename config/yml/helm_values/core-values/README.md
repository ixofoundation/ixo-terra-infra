# Helm Chart Configuration Directory

This directory contains various `yml` files used for configuring ixo Helm charts.
Each Helm chart/application can be customized using the corresponding `yml` file. This file allows you to specify configuration settings for the chart. These settings can include environment variables, resource limits (like memory and CPU usage), and other configuration.

### Common Helm Values Info

1. **Environment Variables**:
    - Environment variables are used to configure application/pod settings at runtime.
    - Feel free to add/modify env vars in corresponding app ymls.
    - Example:
      ```yaml
      env:
        - name: APP_ENV
          value: "production"
        - name: DEBUG
          value: "false"
      ```

2. **Resource Limits and Requests**:
    - Kubernetes allows you to set resource limits and requests for the pods involved.
    - Example:
      ```yaml
      resources:
        requests:
          memory: "200Mi"
          cpu: "500m" # or "0.5"
        limits:
          memory: "400Mi"
      ```