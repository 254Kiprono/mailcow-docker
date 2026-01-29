#!/bin/bash

# ==============================================================================
# Mailcow Deployment Script for Server
# ==============================================================================
# This script prepares and deploys Mailcow with the existing e-commerce stack
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAILCOW_DIR="${SCRIPT_DIR}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ==============================================================================
# Step 1: Check Prerequisites
# ==============================================================================
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    # Check if docker-compose is available
    if ! command -v docker-compose &> /dev/null; then
        print_error "docker-compose is not installed."
        exit 1
    fi
    
    # Check if external network exists
    if ! docker network ls | grep -q "e-c-deployerscript_e-commerce-network"; then
        print_error "External network 'e-c-deployerscript_e-commerce-network' not found."
        print_warn "Please start the e-commerce stack first:"
        print_warn "  cd ../e-c-deployerscript && docker-compose up -d"
        exit 1
    fi
    
    print_info "Prerequisites check passed!"
}

# ==============================================================================
# Step 2: Setup Environment Configuration
# ==============================================================================
setup_environment() {
    print_info "Setting up environment configuration..."
    
    if [ ! -f "${MAILCOW_DIR}/mailcow.conf" ]; then
        if [ -f "${MAILCOW_DIR}/mailcow.conf.example" ]; then
            cp "${MAILCOW_DIR}/mailcow.conf.example" "${MAILCOW_DIR}/mailcow.conf"
            
            # Generate random API keys
            API_KEY=$(openssl rand -hex 16)
            API_KEY_RO=$(openssl rand -hex 16)
            SOGO_KEY=$(openssl rand -hex 16)
            
            # Update the config file
            sed -i "s/GENERATE_ON_SERVER/${API_KEY}/g" "${MAILCOW_DIR}/mailcow.conf"
            sed -i "s/API_KEY_READ_ONLY=GENERATE_ON_SERVER/API_KEY_READ_ONLY=${API_KEY_RO}/g" "${MAILCOW_DIR}/mailcow.conf"
            sed -i "s/SOGO_URL_ENCRYPTION_KEY=GENERATE_ON_SERVER/SOGO_URL_ENCRYPTION_KEY=${SOGO_KEY}/g" "${MAILCOW_DIR}/mailcow.conf"
            
            print_info "Environment configuration created: mailcow.conf"
            print_warn "Review and update mailcow.conf if needed before deployment"
        else
            print_error "mailcow.conf.example not found!"
            exit 1
        fi
    else
        print_info "Using existing mailcow.conf"
    fi
}

# ==============================================================================
# Step 3: Verify Database Connection
# ==============================================================================
verify_database() {
    print_info "Verifying database configuration..."
    
    # Source the config
    source "${MAILCOW_DIR}/mailcow.conf"
    
    # Check if hkup-db-service is running
    if ! docker ps | grep -q "hkup-db-service"; then
        print_error "hkup-db-service is not running!"
        print_warn "Start it with: cd ../e-c-deployerscript && docker-compose up -d hkup-db-service"
        exit 1
    fi
    
    print_info "Database configuration verified!"
    print_warn "Make sure the mailcow database exists:"
    print_warn "  CREATE DATABASE mailcow CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    print_warn "  CREATE USER 'mailco-user'@'%' IDENTIFIED BY 'pass1234!';"
    print_warn "  GRANT ALL PRIVILEGES ON mailcow.* TO 'mailco-user'@'%';"
    print_warn "  FLUSH PRIVILEGES;"
}

# ==============================================================================
# Step 4: Setup SSL Certificates
# ==============================================================================
setup_ssl() {
    print_info "SSL Certificate Setup"
    
    if [ -f "${MAILCOW_DIR}/setup-ssl.sh" ]; then
        chmod +x "${MAILCOW_DIR}/setup-ssl.sh"
        print_info "Running SSL setup script..."
        "${MAILCOW_DIR}/setup-ssl.sh"
    else
        print_warn "SSL setup script not found. Skipping SSL setup."
        print_warn "You can run ./setup-ssl.sh manually later."
    fi
}

# ==============================================================================
# Step 5: Pull Docker Images
# ==============================================================================
pull_images() {
    print_info "Pulling Mailcow Docker images (this may take a while)..."
    cd "${MAILCOW_DIR}"
    docker-compose pull
}

# ==============================================================================
# Step 6: Start Mailcow Services
# ==============================================================================
start_services() {
    print_info "Starting Mailcow services..."
    cd "${MAILCOW_DIR}"
    
    # Start services (excluding disabled ones)
    docker-compose up -d
    
    print_info "Mailcow services started!"
    print_info "Waiting for services to initialize (30 seconds)..."
    sleep 30
}

# ==============================================================================
# Step 7: Verify Deployment
# ==============================================================================
verify_deployment() {
    print_info "Verifying deployment..."
    
    cd "${MAILCOW_DIR}"
    docker-compose ps
    
    echo ""
    print_info "Deployment complete!"
    echo ""
    echo "======================================"
    echo "  Mailcow Access Information"
    echo "======================================"
    echo "Web UI: https://mailcow.devsinkenya.com"
    echo "        https://mail-admin.devsinkenya.com"
    echo ""
    echo "Default admin credentials:"
    echo "  Username: admin"
    echo "  Password: moohoo"
    echo ""
    echo "IMPORTANT: Change the default password immediately!"
    echo "======================================"
    echo ""
    print_warn "Check logs with: docker-compose logs -f"
    print_warn "Navigate to the web UI to complete setup"
}

# ==============================================================================
# Main Deployment Flow
# ==============================================================================
main() {
    echo ""
    echo "======================================"
    echo "  Mailcow Deployment Script"
    echo "======================================"
    echo "This script will:"
    echo "1. Check prerequisites"
    echo "2. Setup environment configuration"
    echo "3. Verify database connection"
    echo "4. Setup SSL certificates"
    echo "5. Pull Docker images"
    echo "6. Start Mailcow services"
    echo "7. Verify deployment"
    echo "======================================"
    echo ""
    
    read -p "Do you want to proceed? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Deployment cancelled."
        exit 0
    fi
    
    check_prerequisites
    setup_environment
    verify_database
    setup_ssl
    pull_images
    start_services
    verify_deployment
}

# Run main function
main
