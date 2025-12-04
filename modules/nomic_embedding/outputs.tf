output "service_name" {
  description = "Name of the Kubernetes service"
  value       = var.application_name
}

output "service_url" {
  description = "Internal service URL for the embedding API"
  value       = "http://${var.application_name}.${var.namespace}.svc.cluster.local"
}

output "service_port" {
  description = "Service port"
  value       = 80
}

output "api_port" {
  description = "Container port for the API"
  value       = 8080
}

output "namespace" {
  description = "Kubernetes namespace"
  value       = var.namespace
}

output "ingress_url" {
  description = "External URL if ingress is enabled"
  value       = var.enable_ingress ? "https://${var.host}" : ""
}

output "backend_info" {
  description = "Information about the selected backend"
  value = {
    backend = var.backend
    model_name = local.model_name
    memory_limit = local.memory_limit
    cpu_limit = local.cpu_limit
    description = {
      vllm = "vLLM V1 with native embedding support (2025)"
      llama_cpp = "Lightweight llama.cpp server with GGUF quantization"
    }[var.backend]
  }
}

output "model_info" {
  description = "Information about the deployed model"
  value = {
    model_name = "nomic-embed-text-v2-moe"
    model_type = "Mixture of Experts Embedding Model"
    multilingual = true
    languages_supported = "~100 languages"
    embedding_dimension = "768 (with Matryoshka support down to 256)"
    context_window = "512 tokens"
    quantization = var.backend == "llama_cpp" ? "Q4_K_M (328MB)" : "Full precision"
    memory_usage = {
      vllm = "~2-3GB"
      llama_cpp = "~800MB-1.2GB"
    }[var.backend]
  }
}

output "api_endpoints" {
  description = "Available API endpoints"
  value = {
    embeddings = "/v1/embeddings"
    health = "/health"
    models = "/v1/models"
  }
}

output "usage_examples" {
  description = "API usage examples for different clients"
  value = {
    curl_example = <<-EOF
      # OpenAI-compatible API (vLLM/llama.cpp)
      curl -X POST http://${var.application_name}.${var.namespace}.svc.cluster.local/v1/embeddings \
        -H "Content-Type: application/json" \
        -d '{
          "input": "search_query: Your text here",
          "model": "${local.model_name}"
        }'
    EOF
    
    python_example = <<-EOF
      # Using OpenAI-compatible client
      from openai import OpenAI
      
      client = OpenAI(
          base_url="http://${var.application_name}.${var.namespace}.svc.cluster.local",
          api_key="not-needed"
      )
      
      # For documents
      doc_response = client.embeddings.create(
          model="${local.model_name}",
          input="search_document: Your document text here"
      )
      
      # For queries  
      query_response = client.embeddings.create(
          model="${local.model_name}",
          input="search_query: Your search query here"
      )
    EOF
    
    prefix_usage = <<-EOF
      # Required prefixes for Nomic models:
      # For documents to be searched: "search_document: "
      # For search queries: "search_query: "
      # For clustering/classification: "clustering: "
      # For retrieval: "retrieval: "
    EOF
  }
}

output "performance_comparison" {
  description = "Performance comparison of different backends"
  value = {
    vllm = {
      reliability = "High"
      setup_complexity = "Medium"
      memory_usage = "Medium (2-3GB)"
      startup_time = "Slow (~3min)"
      api_compatibility = "OpenAI compatible"
      recommended_for = "High throughput, OpenAI API compatibility"
      model_support = "Full nomic-embed-text-v2-moe model from HuggingFace"
    }
    
    llama_cpp = {
      reliability = "High"
      setup_complexity = "Medium"
      memory_usage = "Lowest (800MB-1.2GB)"
      startup_time = "Fast (~60s)"
      api_compatibility = "OpenAI compatible"
      recommended_for = "Resource-constrained environments, exact model match"
      model_support = "Q4_K_M quantized nomic-embed-text-v2-moe (328MB)"
    }
  }
}

output "troubleshooting" {
  description = "Common troubleshooting steps"
  value = {
    startup_issues = "Check logs for model download progress and memory availability"
    api_not_responding = "Verify health endpoint: /health"
    memory_issues = "Reduce batch size or increase memory limits, consider llama_cpp backend"
    performance_issues = "llama_cpp backend provides best resource efficiency for your constraints"
    model_not_found = "Model downloads from HuggingFace automatically (vLLM) or via wget (llama.cpp)"
    exact_model_confirmation = "This module deploys the exact model you requested: text-embedding-nomic-embed-text-v2-moe"
  }
} 