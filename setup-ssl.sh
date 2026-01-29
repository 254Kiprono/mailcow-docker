#!/bin/bash

# ==============================================================================
# Mailcow SSL Certificate Setup Script
# ==============================================================================
# This script sets up SSL certificates for Mailcow domains
# It supports both self-signed certificates (for testing) and Let's Encrypt
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAILCOW_DIR="${SCRIPT_DIR}"
SSL_DIR="${MAILCOW_DIR}/data/assets/ssl"
CERT_DIR="${SSL_DIR}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ==============================================================================
# Configuration
# ==============================================================================
MAILCOW_HOSTNAME="${MAILCOW_HOSTNAME:-mailcow.devsinkenya.com}"
ADDITIONAL_DOMAINS="${ADDITIONAL_SAN:-mail-admin.devsinkenya.com}"

# ==============================================================================
# Functions
# ==============================================================================

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    print_info "Checking prerequisites..."
    
    if ! command -v openssl &> /dev/null; then
        print_error "OpenSSL is not installed. Please install it first."
        exit 1
    fi
    
    if [ ! -d "${SSL_DIR}" ]; then
        print_info "Creating SSL directory: ${SSL_DIR}"
        mkdir -p "${SSL_DIR}"
    fi
}

generate_self_signed_cert() {
    print_info "Generating self-signed certificate for ${MAILCOW_HOSTNAME}..."
    
    # Create private key
    openssl genrsa -out "${CERT_DIR}/key.pem" 4096
    
    # Create certificate signing request
    openssl req -new -key "${CERT_DIR}/key.pem" -out "${CERT_DIR}/cert.csr" \
        -subj "/C=KE/ST=Nairobi/L=Nairobi/O=DevsInKenya/CN=${MAILCOW_HOSTNAME}"
    
    # Create self-signed certificate (valid for 365 days)
    openssl x509 -req -days 365 -in "${CERT_DIR}/cert.csr" \
        -signkey "${CERT_DIR}/key.pem" -out "${CERT_DIR}/cert.pem"
    
    # Create combined certificate
    cat "${CERT_DIR}/cert.pem" "${CERT_DIR}/key.pem" > "${CERT_DIR}/combined.pem"
    
    # Set proper permissions
    chmod 600 "${CERT_DIR}/key.pem"
    chmod 644 "${CERT_DIR}/cert.pem"
    
    print_info "Self-signed certificate generated successfully!"
    print_warn "Note: Self-signed certificates will show security warnings in browsers."
}

setup_letsencrypt() {
    print_info "Setting up Let's Encrypt certificate..."
    print_warn "Make sure:"
    print_warn "  1. DNS records point to your server"
    print_warn "  2. Ports 80 and 443 are accessible"
    print_warn "  3. nginx-ec is running with ACME challenge configured"
    
    read -p "Continue with Let's Encrypt setup? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Skipping Let's Encrypt setup."
        return
    fi
    
    print_info "Starting acme-mailcow container for certificate generation..."
    
    # Start only acme-mailcow and its dependencies
    cd "${MAILCOW_DIR}"
    docker-compose up -d unbound-mailcow nginx-mailcow acme-mailcow
    
    print_info "Waiting for ACME container to generate certificates (this may take a minute)..."
    sleep 30
    
    # Check if certificate was generated
    if [ -f "${CERT_DIR}/cert.pem" ]; then
        print_info "Let's Encrypt certificate generated successfully!"
    else
        print_error "Certificate generation failed. Check logs with: docker-compose logs acme-mailcow"
        exit 1
    fi
}

copy_existing_certs() {
    print_info "Using existing certificates from nginx-ec..."
    
    NGINX_CERT_DIR="${SCRIPT_DIR}/../e-c-deployerscript/cert"
    
    if [ ! -f "${NGINX_CERT_DIR}/origin.pem" ] || [ ! -f "${NGINX_CERT_DIR}/private.key" ]; then
        print_error "Certificate files not found in ${NGINX_CERT_DIR}"
        return 1
    fi
    
    # Copy certificates
    cp "${NGINX_CERT_DIR}/origin.pem" "${CERT_DIR}/cert.pem"
    cp "${NGINX_CERT_DIR}/private.key" "${CERT_DIR}/key.pem"
    
    # Create combined certificate
    cat "${CERT_DIR}/cert.pem" "${CERT_DIR}/key.pem" > "${CERT_DIR}/combined.pem"
    
    # Set proper permissions
    chmod 600 "${CERT_DIR}/key.pem"
    chmod 644 "${CERT_DIR}/cert.pem"
    
    print_info "Existing certificates copied successfully!"
}

display_menu() {
    echo ""
    echo "======================================"
    echo "  Mailcow SSL Certificate Setup"
    echo "======================================"
    echo "1) Use existing nginx-ec certificates (Recommended)"
    echo "2) Generate self-signed certificate (Testing only)"
    echo "3) Setup Let's Encrypt (Production)"
    echo "4) Skip certificate setup"
    echo "======================================"
    read -p "Select an option (1-4): " choice
    echo ""
    
    case $choice in
        1)
            copy_existing_certs
            ;;
        2)
            generate_self_signed_cert
            ;;
        3)
            setup_letsencrypt
            ;;
        4)
            print_info "Skipping certificate setup."
            ;;
        *)
            print_error "Invalid option. Exiting."
            exit 1
            ;;
    esac
}

verify_certificates() {
    print_info "Verifying certificate setup..."
    
    if [ -f "${CERT_DIR}/cert.pem" ] && [ -f "${CERT_DIR}/key.pem" ]; then
        # Check certificate validity
        openssl x509 -in "${CERT_DIR}/cert.pem" -noout -text | grep -E "(Subject:|Issuer:|Not Before|Not After )"
        print_info "Certificate verification complete!"
    else
        print_error "Certificates not found at ${CERT_DIR}"
        exit 1
    fi
}

# ==============================================================================
# Main Script
# ==============================================================================

main() {
    echo ""
    echo "======================================"
    echo "  Mailcow SSL Setup"
    echo "======================================"
    echo "Mailcow Hostname: ${MAILCOW_HOSTNAME}"
    echo "Additional Domains: ${ADDITIONAL_DOMAINS}"
    echo "Certificate Directory: ${CERT_DIR}"
    echo "======================================"
    echo ""
    
    check_prerequisites
    display_menu
    
    if [ $? -eq 0 ]; then
        verify_certificates
        echo ""
        print_info "SSL certificate setup complete!"
        print_info "You can now start Mailcow services."
    fi
}

# Run main function
main
