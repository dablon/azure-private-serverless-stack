#!/usr/bin/env bash
# ============================================
# Docker Test Runner - Azure Private Serverless Stack
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
TEST_MODE="${TEST_MODE:-all}"
COVERAGE_THRESHOLD="${COVERAGE_THRESHOLD:-90}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ============================================
# Helper Functions
# ============================================

print_header() {
    echo -e "${BLUE}========================================"
    echo -e "  Azure Private Serverless Stack"
    echo -e "  Docker Test Runner"
    echo -e "========================================${NC}"
}

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker compose &> /dev/null && ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    print_status "Docker: $(docker --version)"
    print_status "Docker Compose: $(docker compose version 2>/dev/null || docker-compose --version)"
}

build_images() {
    print_status "Building test images..."
    cd "$PROJECT_ROOT/docker"
    docker compose build
    print_status "Images built successfully"
}

# ============================================
# Main Commands
# ============================================

run_pester() {
    print_status "Running Pester Tests..."
    docker compose run --rm pester-tests
}

run_terraform() {
    print_status "Running Terraform Validate..."
    docker compose run --rm terraform-validate
}

run_security() {
    print_status "Running Security Scans..."
    echo "--- Checkov ---"
    docker compose run --rm security-scan
    echo "--- TFSec ---"
    docker compose run --rm tfsec-scan
}

run_full() {
    print_status "Running Full Test Suite..."
    docker compose run --rm full-test-suite
}

run_lint() {
    print_status "Running Linting..."
    docker compose run --rm lint
}

cleanup() {
    print_status "Cleaning up containers and volumes..."
    cd "$PROJECT_ROOT/docker"
    docker compose down -v --remove-orphans
    print_status "Cleanup complete"
}

help() {
    print_header
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  pester        Run Pester unit and E2E tests"
    echo "  terraform     Run Terraform validate and plan"
    echo "  security      Run security scans (checkov + tfsec)"
    echo "  full          Run complete test suite"
    echo "  lint          Run linting"
    echo "  build         Build Docker images"
    echo "  clean         Clean up containers and volumes"
    echo "  help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 pester"
    echo "  $0 full"
    echo "  $0 security"
    echo ""
    echo "Environment Variables:"
    echo "  TEST_MODE           Test mode (all/pester/terraform/security)"
    echo "  COVERAGE_THRESHOLD  Minimum coverage percentage (default: 90)"
    echo ""
}

# ============================================
# Main Execution
# ============================================

main() {
    check_docker
    build_images
    
    COMMAND="${1:-help}"
    
    case "$COMMAND" in
        pester)
            run_pester
            ;;
        terraform)
            run_terraform
            ;;
        security)
            run_security
            ;;
        full)
            run_full
            ;;
        lint)
            run_lint
            ;;
        build)
            print_status "Images built"
            ;;
        clean)
            cleanup
            ;;
        help|--help|-h)
            help
            ;;
        *)
            print_error "Unknown command: $COMMAND"
            help
            exit 1
            ;;
    esac
}

main "$@"
