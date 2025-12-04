variable "application_name" {
  type        = string
  default     = "nomic-embedding"
  description = "Name of the application"
}

variable "namespace" {
  type        = string
  default     = "nomic-embedding"
  description = "Kubernetes namespace for the application"
}

variable "create_namespace" {
  type        = bool
  default     = true
  description = "Whether to create the namespace"
}

variable "backend" {
  type        = string
  default     = "llama_cpp"
  description = "Backend to use: 'llama_cpp' (exact model, 800MB-1.2GB) or 'vllm' (vLLM V1, 2-3GB)"
  validation {
    condition     = contains(["llama_cpp", "vllm"], var.backend)
    error_message = "Backend must be 'llama_cpp' or 'vllm'. Note: Only these backends support the exact nomic-embed-text-v2-moe model."
  }
}

# llama.cpp specific variables
variable "llama_cpp_image" {
  type        = string
  default     = "ghcr.io/ggml-org/llama.cpp:server-cuda-b6107"
  description = "Docker image for llama.cpp server (latest version)"
}

variable "cpu_request" {
  type        = string
  default     = "500m"
  description = "CPU request for llama.cpp container"
}

variable "cpu_limit" {
  type        = string
  default     = "1000m"
  description = "CPU limit for llama.cpp container"
}

variable "memory_request" {
  type        = string
  default     = "800Mi"
  description = "Memory request for llama.cpp container"
}

variable "memory_limit" {
  type        = string
  default     = "1.5Gi"
  description = "Memory limit for llama.cpp container"
}

variable "cpu_threads" {
  type        = number
  default     = 2
  description = "Number of CPU threads for llama.cpp server"
}

# vLLM specific variables
variable "vllm_cpu_request" {
  type        = string
  default     = "1000m"
  description = "CPU request for vLLM container"
}

variable "vllm_cpu_limit" {
  type        = string
  default     = "2000m"
  description = "CPU limit for vLLM container"
}

variable "vllm_memory_request" {
  type        = string
  default     = "2Gi"
  description = "Memory request for vLLM container"
}

variable "vllm_memory_limit" {
  type        = string
  default     = "3Gi"
  description = "Memory limit for vLLM container"
}

variable "max_batch_size" {
  type        = number
  default     = 8
  description = "Maximum batch size for vLLM server"
}

variable "llama_batch_size" {
  type        = number
  default     = 2048
  description = "Physical batch size for llama.cpp server (must be >= input tokens, recommended to match context size)"
}

variable "llama_context_size" {
  type        = number
  default     = 2048
  description = "Context size for llama.cpp server (maximum number of tokens that can be processed in a single request)"
}

# Storage configuration (only used for llama.cpp)
variable "storage_class" {
  type        = string
  default     = ""
  description = "Storage class for PVC (empty for default, only used for llama.cpp backend)"
}

# Ingress configuration
variable "enable_ingress" {
  type        = bool
  default     = false
  description = "Whether to create an ingress resource"
}

variable "host" {
  type        = string
  default     = ""
  description = "Hostname for ingress (required if enable_ingress is true)"
}

variable "ingress_class" {
  type        = string
  default     = "nginx"
  description = "Ingress class to use"
}

variable "ingress_annotations" {
  type        = map(string)
  default     = {}
  description = "Additional annotations for ingress"
}

variable "enable_tls" {
  type        = bool
  default     = false
  description = "Whether to enable TLS for ingress"
} 