#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Infracost is installed
if ! command -v infracost &> /dev/null; then
    print_error "Infracost is not installed. Please install it first:"
    echo "  curl -fsSL https://raw.githubusercontent.com/infracost/infracost/master/scripts/install.sh | sh"
    exit 1
fi

# Check if API key is configured
if ! infracost configure get api_key &> /dev/null; then
    print_warning "Infracost API key is not configured. You can get a free API key at https://dashboard.infracost.io"
    print_info "To configure: infracost configure set api_key <your_api_key>"
    print_info "Continuing with demo/cached pricing data..."
fi

# Function to run cost estimate for a specific environment
estimate_environment() {
    local env=$1
    local output_format=${2:-table}
    
    print_info "Estimating costs for environment: $env"
    
    # Create output directory if it doesn't exist
    mkdir -p cost-estimates
    
    # Run Infracost breakdown
    if [[ "$output_format" == "json" ]]; then
        infracost breakdown \
            --path . \
            --terraform-workspace "$env" \
            --terraform-var-file terraform.tfvars \
            --usage-file infracost-usage.yml \
            --format json \
            --out-file "cost-estimates/${env}-costs.json"
        
        print_success "Cost estimate saved to cost-estimates/${env}-costs.json"
    else
        infracost breakdown \
            --path . \
            --terraform-workspace "$env" \
            --terraform-var-file terraform.tfvars \
            --usage-file infracost-usage.yml \
            --format table \
            --out-file "cost-estimates/${env}-costs.txt"
        
        print_success "Cost estimate saved to cost-estimates/${env}-costs.txt"
        
        # Also display on screen
        echo ""
        echo "=== Cost Estimate for $env ==="
        cat "cost-estimates/${env}-costs.txt"
        echo ""
    fi
}

# Function to compare costs between environments
compare_environments() {
    print_info "Comparing costs between environments..."
    
    # Get list of available workspaces
    workspaces=$(terraform workspace list | grep -v "^\*" | tr -d ' ')
    
    # Generate JSON outputs for comparison
    for env in $workspaces; do
        if [[ "$env" != "default" ]]; then
            print_info "Generating cost data for $env..."
            infracost breakdown \
                --path . \
                --terraform-workspace "$env" \
                --terraform-var-file terraform.tfvars \
                --usage-file infracost-usage.yml \
                --format json \
                --out-file "cost-estimates/${env}-costs.json"
        fi
    done
    
    # Create comparison reports for available environments
    workspace_array=($workspaces)
    for ((i=0; i<${#workspace_array[@]}-1; i++)); do
        env1="${workspace_array[i]}"
        env2="${workspace_array[i+1]}"
        
        if [[ "$env1" != "default" && "$env2" != "default" ]]; then
            if [[ -f "cost-estimates/${env1}-costs.json" ]] && [[ -f "cost-estimates/${env2}-costs.json" ]]; then
                infracost diff \
                    --path1 "cost-estimates/${env1}-costs.json" \
                    --path2 "cost-estimates/${env2}-costs.json" \
                    --format table \
                    --out-file "cost-estimates/${env1}-vs-${env2}.txt"
                
                print_success "Comparison saved to cost-estimates/${env1}-vs-${env2}.txt"
            fi
        fi
    done
}

# Function to estimate costs using the config file
estimate_with_config() {
    print_info "Running cost estimation using infracost.yml config..."
    
    infracost breakdown \
        --config-file infracost.yml \
        --format table \
        --out-file "cost-estimates/all-environments.txt"
    
    print_success "All environments cost estimate saved to cost-estimates/all-environments.txt"
    
    # Display summary
    echo ""
    echo "=== Cost Summary for All Environments ==="
    cat "cost-estimates/all-environments.txt"
    echo ""
}

# Function to generate cost report
generate_report() {
    print_info "Generating comprehensive cost report..."
    
    # Create report directory
    mkdir -p cost-reports
    
    # Generate HTML report
    infracost breakdown \
        --config-file infracost.yml \
        --format html \
        --out-file "cost-reports/ixo-infrastructure-costs.html"
    
    # Generate JSON for further analysis
    infracost breakdown \
        --config-file infracost.yml \
        --format json \
        --out-file "cost-reports/ixo-infrastructure-costs.json"
    
    print_success "HTML report saved to cost-reports/ixo-infrastructure-costs.html"
    print_success "JSON report saved to cost-reports/ixo-infrastructure-costs.json"
    
    # Remind user about Vultr costs
    echo ""
    print_info "📋 For complete cost estimates including Vultr VKE infrastructure:"
    echo "   👉 Check README-vultr-cost-estimates.md for detailed breakdowns"
    echo "   👉 Infracost only covers AWS/GCP resources, not Vultr VKE costs"
    echo ""
}

# Main script logic
case "${1:-}" in
    "devnet"|"testnet"|"mainnet")
        estimate_environment "$1" "${2:-table}"
        echo ""
        print_info "💡 Note: These costs only include AWS/GCP resources"
        print_info "📋 For complete cost estimates including Vultr VKE infrastructure:"
        echo "   👉 Check README-vultr-cost-estimates.md"
        echo ""
        ;;
    *)
        # Check if it's a valid workspace
        if terraform workspace list | grep -q "^[[:space:]]*$1"; then
            estimate_environment "$1" "${2:-table}"
            echo ""
            print_info "💡 Note: These costs only include AWS/GCP resources"
            print_info "📋 For complete cost estimates including Vultr VKE infrastructure:"
            echo "   👉 Check README-vultr-cost-estimates.md"
            echo ""
        else
            case "${1:-}" in
                "compare")
                    compare_environments
                    ;;
                "config")
                    estimate_with_config
                    ;;
                "report")
                    generate_report
                    ;;
                "all")
                    print_info "Running comprehensive cost analysis..."
                    estimate_with_config
                    compare_environments
                    generate_report
                    ;;
                *)
                    echo "Usage: $0 [environment_name|compare|config|report|all] [json|table]"
                    echo ""
                    echo "Environment Commands:"
                    echo "  environment_name            - Estimate costs for specific environment"
                    echo "                               (use your Terraform workspace name)"
                    echo ""
                    echo "Available workspaces:"
                    terraform workspace list | grep -v "^\*" | sed 's/^/  /'
                    echo ""
                    echo "Analysis Commands:"
                    echo "  compare                     - Compare costs between environments"
                    echo "  config                      - Use infracost.yml to estimate all environments"
                    echo "  report                      - Generate comprehensive HTML/JSON reports"
                    echo "  all                         - Run all cost analysis commands"
                    echo ""
                    echo "Output formats (optional second parameter):"
                    echo "  table                       - Human-readable table format (default)"
                    echo "  json                        - Machine-readable JSON format"
                    echo ""
                    echo "Examples:"
                    echo "  $0 your_dev_env             - Estimate costs for your development environment"
                    echo "  $0 your_prod_env json       - Estimate production costs in JSON format"
                    echo "  $0 devnet                   - Estimate costs for devnet (IXO reference)"
                    echo "  $0 compare                  - Compare costs between all environments"
                    echo "  $0 all                      - Run complete cost analysis"
                    echo ""
                    echo "📋 Documentation:"
                    echo "  README-cost-estimation.md     - Complete cost estimation guide"
                    echo "  README-vultr-cost-estimates.md - Vultr pricing breakdown"
                    echo ""
                    echo "💡 Tip: Create your own environment names like 'mycompany_dev' instead of using"
                    echo "    the IXO-specific names (devnet/testnet/mainnet)"
                    ;;
            esac
        fi
        ;;
esac 