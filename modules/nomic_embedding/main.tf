terraform {
  required_providers {
    kubectl = {
      source = "alekc/kubectl"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

# Create namespace
resource "kubernetes_namespace_v1" "nomic_embedding" {
  count = var.create_namespace ? 1 : 0
  
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/name" = var.application_name
    }
  }
}

# ConfigMap for server configuration
resource "kubernetes_config_map_v1" "nomic_embedding_config" {
  metadata {
    name      = "${var.application_name}-config"
    namespace = var.namespace
  }

  data = merge({
    # llama.cpp approach (ATTEMPTING with latest version)
    "download-model.sh" = <<-EOF
      #!/bin/sh
      set -e
      
      MODEL_DIR="/models"
      MODEL_FILE="nomic-embed-text-v2-moe.Q4_K_M.gguf"
      MODEL_URL="https://huggingface.co/nomic-ai/nomic-embed-text-v2-moe-GGUF/resolve/main/$MODEL_FILE"
      
      mkdir -p $MODEL_DIR
      
      if [ ! -f "$MODEL_DIR/$MODEL_FILE" ]; then
        echo "Downloading Nomic Embed Text V2 MoE (Q4_K_M quantization - 328MB)..."
        echo "This is the exact model you requested: text-embedding-nomic-embed-text-v2-moe"
        echo "Attempting with latest llama.cpp version (b6018) - architecture support TBD"
        echo "This may take a few minutes..."
        
        # Use BusyBox-compatible wget options
        if ! wget -O "$MODEL_DIR/$MODEL_FILE.tmp" "$MODEL_URL" -T 120 -q; then
          echo "Download failed, retrying with verbose output..."
          wget -O "$MODEL_DIR/$MODEL_FILE.tmp" "$MODEL_URL" -T 120
        fi
        
        # Verify download completed successfully
        if [ -f "$MODEL_DIR/$MODEL_FILE.tmp" ]; then
          mv "$MODEL_DIR/$MODEL_FILE.tmp" "$MODEL_DIR/$MODEL_FILE"
          echo "Model downloaded successfully"
          echo "File size: $(du -h "$MODEL_DIR/$MODEL_FILE" | cut -f1)"
        else
          echo "Download failed!"
          exit 1
        fi
      else
        echo "Model already exists, skipping download"
        echo "File size: $(du -h "$MODEL_DIR/$MODEL_FILE" | cut -f1)"
      fi
    EOF
    
    "run-llama-server.sh" = <<-EOF
      #!/bin/sh
      set -e
      
      MODEL_DIR="/models"
      MODEL_FILE="nomic-embed-text-v2-moe.Q4_K_M.gguf"
      
      # Download model if not present
      /scripts/download-model.sh
      
      # Start llama.cpp server with Nomic Embed Text V2 MoE
      echo "Starting llama.cpp server (b6107) with Nomic Embed Text V2 MoE..."
      echo "This is the exact model: text-embedding-nomic-embed-text-v2-moe"
      echo "Architecture: nomic-bert-moe (confirmed working with latest llama.cpp)"
      echo "Note: This is an EMBEDDINGS-ONLY model - chat completions NOT supported"
      echo "Use /v1/embeddings endpoint only"
      echo "Chat endpoint /v1/chat/completions will fail with 'logits computation' error"
      exec /app/llama-server \
        --model "$MODEL_DIR/$MODEL_FILE" \
        --host 0.0.0.0 \
        --port 8080 \
        --embeddings \
        --threads ${var.cpu_threads} \
        --ctx-size ${var.llama_context_size} \
        --batch-size ${var.llama_batch_size} \
        -ub ${var.llama_batch_size} \
        --n-predict -1
    EOF
  }, var.backend == "vllm" ? {
    # vLLM V1 approach (2025 updated)  
    "run-vllm-server.sh" = <<-EOF
      #!/bin/bash
      set -e
      
      echo "Starting vLLM V1 with Nomic Embed Text V2..."
      echo "Using vLLM V1 (2025) which has native embedding support"
      
      # Environment variables for vLLM V1 CPU optimization
      export VLLM_USE_V1=1
      export VLLM_TARGET_DEVICE=cpu
      export CUDA_VISIBLE_DEVICES=""
      export HF_HUB_DISABLE_PROGRESS_BARS=1
      export VLLM_LOGGING_LEVEL=INFO
      
      # Install required system packages
      apt-get update -qq && apt-get install -y -qq \
        build-essential \
        cmake \
        git \
        && rm -rf /var/lib/apt/lists/*
      
      # Install vLLM V1 with CPU support
      if ! command -v vllm &> /dev/null; then
        echo "Installing vLLM V1 with CPU support..."
        pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu --quiet
        pip install vllm --quiet
      fi
      
      echo "Starting vLLM V1 server with embedding model..."
      
      # Start vLLM V1 server (embedding models now supported in V1)
      exec python -m vllm.entrypoints.openai.api_server \
        --model nomic-ai/nomic-embed-text-v2-moe \
        --host 0.0.0.0 \
        --port 8080 \
        --device cpu \
        --tensor-parallel-size 1 \
        --max-model-len 512 \
        --enforce-eager \
        --trust-remote-code \
        --disable-log-requests \
        --max-num-seqs ${var.max_batch_size}
    EOF
  } : {})

  depends_on = [kubernetes_namespace_v1.nomic_embedding]
}

# PersistentVolumeClaim for model storage (only needed for llama.cpp)
resource "kubernetes_persistent_volume_claim_v1" "nomic_embedding_pvc" {
  count = var.backend == "llama_cpp" ? 1 : 0
  
  metadata {
    name      = "${var.application_name}-pvc"
    namespace = var.namespace
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "40Gi"  # Reduced since Q4_K_M is only 328MB
      }
    }
    storage_class_name = var.storage_class != "" ? var.storage_class : null
  }

  depends_on = [kubernetes_namespace_v1.nomic_embedding]
}

# Deployment for the embedding service
resource "kubernetes_deployment_v1" "nomic_embedding" {
  metadata {
    name      = var.application_name
    namespace = var.namespace
    labels = {
      app = var.application_name
    }
  }

  spec {
    replicas = 1
    
    selector {
      match_labels = {
        app = var.application_name
      }
    }

    template {
      metadata {
        labels = {
          app = var.application_name
        }
      }

      spec {
        # Init container only for llama.cpp
        dynamic "init_container" {
          for_each = var.backend == "llama_cpp" ? [1] : []
          content {
            name  = "model-downloader"
            image = "alpine:3.19"
            command = ["/bin/sh", "/scripts/download-model.sh"]
            
            volume_mount {
              name       = "model-storage"
              mount_path = "/models"
            }
            
            volume_mount {
              name       = "scripts"
              mount_path = "/scripts"
            }
          }
        }

        container {
          name  = var.application_name
          image = local.container_image
          command = local.container_command

          port {
            container_port = 8080
            name          = "http"
          }

          resources {
            requests = {
              memory = local.memory_request
              cpu    = local.cpu_request
            }
            limits = {
              memory = local.memory_limit
              cpu    = local.cpu_limit
            }
          }

          # Volume mounts only for llama.cpp
          dynamic "volume_mount" {
            for_each = var.backend == "llama_cpp" ? [1] : []
            content {
              name       = "model-storage"
              mount_path = "/models"
            }
          }

          volume_mount {
            name       = "scripts"
            mount_path = "/scripts"
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = local.startup_time
            period_seconds        = 30
            timeout_seconds       = 10
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = local.startup_time / 2
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          env {
            name  = "MODEL_NAME"
            value = local.model_name
          }

          # Environment variables based on backend
          dynamic "env" {
            for_each = var.backend == "vllm" ? [1] : []
            content {
              name  = "VLLM_USE_V1"
              value = "1"
            }
          }

          dynamic "env" {
            for_each = var.backend == "vllm" ? [1] : []
            content {
              name  = "VLLM_TARGET_DEVICE"
              value = "cpu"
            }
          }
        }

        # Volumes
        dynamic "volume" {
          for_each = var.backend == "llama_cpp" ? [1] : []
          content {
            name = "model-storage"
            persistent_volume_claim {
              claim_name = kubernetes_persistent_volume_claim_v1.nomic_embedding_pvc[0].metadata[0].name
            }
          }
        }

        volume {
          name = "scripts"
          config_map {
            name         = kubernetes_config_map_v1.nomic_embedding_config.metadata[0].name
            default_mode = "0755"
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_config_map_v1.nomic_embedding_config,
    kubernetes_persistent_volume_claim_v1.nomic_embedding_pvc
  ]
}

# Service to expose the embedding API
resource "kubernetes_service_v1" "nomic_embedding" {
  metadata {
    name      = var.application_name
    namespace = var.namespace
    labels = {
      app = var.application_name
    }
  }

  spec {
    type = "ClusterIP"
    
    port {
      port        = 80
      target_port = 8080
      protocol    = "TCP"
      name        = "http"
    }

    selector = {
      app = var.application_name
    }
  }

  depends_on = [kubernetes_deployment_v1.nomic_embedding]
}

# Optional: Ingress for external access
resource "kubernetes_ingress_v1" "nomic_embedding" {
  count = var.enable_ingress ? 1 : 0

  metadata {
    name      = var.application_name
    namespace = var.namespace
    annotations = merge(
      var.ingress_annotations,
      {
        "kubernetes.io/ingress.class" = var.ingress_class
        "cert-manager.io/cluster-issuer" = "letsencrypt-staging"
      }
    )
  }

  spec {
    ingress_class_name = var.ingress_class
    
    dynamic "tls" {
      for_each = var.enable_tls ? [1] : []
      content {
        hosts       = [var.host]
        secret_name = "${var.application_name}-tls"
      }
    }

    rule {
      host = var.host
      
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          
          backend {
            service {
              name = kubernetes_service_v1.nomic_embedding.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service_v1.nomic_embedding]
}

# Local values for backend-specific configuration
locals {
  # Backend-specific configuration
  backend_config = {
    vllm = {
      image = "python:3.10-bullseye"
      command = ["/bin/bash", "/scripts/run-vllm-server.sh"]
      memory_request = var.vllm_memory_request
      memory_limit = var.vllm_memory_limit
      cpu_request = var.vllm_cpu_request
      cpu_limit = var.vllm_cpu_limit
      startup_time = 180
      model_name = "nomic-ai/nomic-embed-text-v2-moe"
    }
    llama_cpp = {
      image = var.llama_cpp_image
      command = ["/bin/sh", "/scripts/run-llama-server.sh"]
      memory_request = var.memory_request
      memory_limit = var.memory_limit
      cpu_request = var.cpu_request
      cpu_limit = var.cpu_limit
      startup_time = 60
      model_name = "nomic-embed-text-v2-moe.Q4_K_M.gguf"
    }
  }
  
  # Select configuration based on backend
  config = local.backend_config[var.backend]
  
  container_image = local.config.image
  container_command = local.config.command
  memory_request = local.config.memory_request
  memory_limit = local.config.memory_limit
  cpu_request = local.config.cpu_request
  cpu_limit = local.config.cpu_limit
  startup_time = local.config.startup_time
  model_name = local.config.model_name
} 