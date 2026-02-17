#!/bin/bash

# OpenTunnel - Simple reverse SSH tunnel
# Usage: ot [minutes] [username] [ssh_key]
# Example: ot 60 root "ssh-ed25519..."

# Debug: show all args FIRST
echo "[DEBUG] All args: '$*'" >&2
echo "[DEBUG] Arg count: $#" >&2

SESSION_ID=$(openssl rand -hex 4 2>/dev/null || date +%s)
TEMP_USER="tunneluser"
EXPIRE_MINUTES=60
BORE_PID=""
SSH_KEY=""

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[+]${NC} $1" >&2; }
log_error() { echo -e "${RED}[x]${NC} $1" >&2; }

# Parse all args
echo "[DEBUG] Starting parse..." >&2
for arg in "$@"; do
    echo "[DEBUG] Processing: '$arg'" >&2
    if [[ "$arg" == -* ]]; then
        echo "[DEBUG] Skipping flag: $arg" >&2
        continue
    elif [[ "$arg" =~ ^ssh- ]]; then
        echo "[DEBUG] Found SSH key: ${arg:0:20}..." >&2
        SSH_KEY="$arg"
    elif [[ "$arg" =~ ^[0-9]+$ ]]; then
        echo "[DEBUG] Found minutes: $arg" >&2
        EXPIRE_MINUTES="$arg"
    elif [ -n "$arg" ]; then
        echo "[DEBUG] Found user: $arg" >&2
        TEMP_USER="$arg"
    fi
done
echo "[DEBUG] After parse - minutes: $EXPIRE_MINUTES, user: $TEMP_USER, key: '${SSH_KEY:0:10}...'" >&2

# If no SSH key provided, prompt for it
if [ -z "$SSH_KEY" ]; then
    echo -n "Enter your SSH public key: "
    read SSH_KEY
fi

if [ -z "$SSH_KEY" ]; then
    log_error "SSH key required"
    exit 1
fi

setup_user_with_key() {
    local user=$1
    local key=$2
    
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
        fi
        sleep 1
    done
    
    log_error "Failed to establish tunnel"
    return 1
}

cleanup() {
    [ -n "$BORE_PID" ] && kill $BORE_PID 2>/dev/null
    pkill -f "bore.*${SESSION_ID}" 2>/dev/null
    rm -f /tmp/ot_bore.log
}

# Main
if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root or with sudo"
    exit 1
fi

log_info "OpenTunnel - ${EXPIRE_MINUTES} minutes, user: ${TEMP_USER}"

if ! install_bore; then
    log_error "Failed to install bore"
    exit 1
fi

setup_user_with_key "$TEMP_USER" "$SSH_KEY"

PORT=$(start_tunnel) || exit 1

echo ""
echo "========================================================"
echo -e "              ${GREEN}CONNECTED${NC}"
echo "========================================================"
echo ""
echo "Tunnel: bore.pub:${PORT}"
echo "User: ${TEMP_USER}"
echo ""
echo "COPY TO YOUR LOCAL MACHINE:"
echo "  bore.pub:${PORT}"
echo ""
echo "========================================================"

trap cleanup EXIT INT TERM

sleep $((EXPIRE_MINUTES * 60))
