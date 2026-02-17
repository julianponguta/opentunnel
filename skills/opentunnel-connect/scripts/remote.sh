#!/bin/bash

SSH_KEY=""
SESSION_ID=$(openssl rand -hex 4 2>/dev/null || date +%s)
TEMP_USER="tunneluser"
EXPIRE_MINUTES=60
BORE_PID=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[+]${NC} $1" >&2; }
log_error() { echo -e "${RED}[x]${NC} $1" >&2; }

usage() {
    echo "Usage: $0 <username> [ssh_key]"
    echo ""
    echo "Arguments:"
    echo "  username   SSH user (default: tunneluser)"
    echo "  ssh_key   SSH public key to add"
    echo ""
    exit 1
}

parse_args() {
    for arg in "$@"; do
        if [[ "$arg" =~ ^ssh- ]]; then
            SSH_KEY="$arg"
        elif [[ ! "$arg" =~ ^- ]]; then
            TEMP_USER="$arg"
        fi
    done
    
    [ -z "$TEMP_USER" ] && TEMP_USER="tunneluser"
}

setup_user_with_key() {
    local user=$1
    local key=$2
    
    log_info "Setting up user with SSH key..."
    
    if [ "$user" = "root" ]; then
        HOME_DIR="/root"
    else
        HOME_DIR="/home/${user}"
    fi
    
    mkdir -p "${HOME_DIR}/.ssh"
    chmod 700 "${HOME_DIR}/.ssh"
    
    if ! grep -qF "$key" "${HOME_DIR}/.ssh/authorized_keys" 2>/dev/null; then
        echo "$key" >> "${HOME_DIR}/.ssh/authorized_keys"
    fi
    chmod 600 "${HOME_DIR}/.ssh/authorized_keys"
    chown -R "${user}:${user}" "${HOME_DIR}/.ssh"
    
    log_info "SSH key added for user ${user}"
}

install_bore() {
    if command -v bore &> /dev/null; then
        return 0
    fi
    
    log_info "Installing bore..."
    
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) BORE_ARCH="x86_64" ;;
        aarch64) BORE_ARCH="aarch64" ;;
        *) BORE_ARCH="x86_64" ;;
    esac
    
    VERSION="0.6.0"
    URL="https://github.com/ekzhang/bore/releases/download/v${VERSION}/bore-v${VERSION}-${BORE_ARCH}-unknown-linux-musl.tar.gz"
    
    if curl -fsSL "$URL" | tar -xz -C /tmp 2>/dev/null; then
        mv /tmp/bore /usr/local/bin/bore
        chmod +x /usr/local/bin/bore
        log_info "bore installed"
        return 0
    fi
    
    return 1
}

start_tunnel() {
    log_info "Starting bore tunnel..."
    
    # Run bore and capture output properly
    bash -c 'bore local 22 --to bore.pub 2>&1' > /tmp/ot_bore.log &
    BORE_PID=$!
    
    for i in $(seq 1 10); do
        if [ -s /tmp/ot_bore.log ]; then
            PORT=$(grep -oE 'bore\.pub:[0-9]+' /tmp/ot_bore.log | head -1 | sed 's/bore\.pub://')
            if [ -n "$PORT" ]; then
                log_info "Tunnel ready on port ${PORT}"
                echo "$PORT"
                return 0
            fi
            # Show output for debugging
            cat /tmp/ot_bore.log >&2
        fi
        sleep 1
    done
    
    log_error "Failed - output was:"
    cat /tmp/ot_bore.log >&2
    return 1
}

cleanup() {
    if [ -n "$BORE_PID" ]; then
        kill $BORE_PID 2>/dev/null || true
    fi
    pkill -f "bore.*${SESSION_ID}" 2>/dev/null || true
    rm -f /tmp/ot_bore.log
}

main() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run as root or with sudo"
        exit 1
    fi
    
    parse_args "$@"
    
    log_info "Starting OpenTunnel Connect..."
    log_info "User: ${TEMP_USER}"
    
    if ! install_bore; then
        log_error "Failed to install bore"
        exit 1
    fi
    
    if [ -n "$SSH_KEY" ]; then
        setup_user_with_key "$TEMP_USER" "$SSH_KEY"
    fi
    
    PORT=$(start_tunnel) || exit 1
    
    echo ""
    echo "========================================================"
    echo -e "              ${GREEN}CONNECTED${NC}"
    echo "========================================================"
    echo ""
    echo "Tunnel: bore.pub:${PORT}"
    echo "User: ${TEMP_USER}"
    echo ""
    echo "COPY THIS TO YOUR LOCAL MACHINE:"
    echo "  bore.pub:${PORT}"
    echo ""
    echo "========================================================"
    
    # Keep running in background
    sleep $((EXPIRE_MINUTES * 60))
    cleanup

trap cleanup EXIT INT TERM

main "$@"
