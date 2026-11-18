apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${ca_certificate}
    server: ${endpoint}
  name: ${cluster_name}
contexts:
- context:
    cluster: ${cluster_name}
    user: ${cluster_name}
  name: ${cluster_name}
current-context: ${cluster_name}
kind: Config
preferences: {}
users:
- name: ${cluster_name}
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: ${aws_cli_path}
      args:
        - "eks"
        - "get-token"
        - "--cluster-name"
        - "${cluster_name}"
        - "--region"
        - "${region}" %{ if aws_profile != null }
      env:
        - name: "AWS_PROFILE"
          value: "${aws_profile}"
        - name: "AWS_ACCESS_KEY_ID"
          value: ""
        - name: "AWS_SECRET_ACCESS_KEY"
          value: ""
        - name: "AWS_SESSION_TOKEN"
          value: ""
%{ endif }