#!/bin/bash

SESSION_ID=$(openssl rand -hex 4 2>/dev/null || echo "$$")
TEMP_USER="tunneluser"
KEY_PATH="/tmp/opentunnel_key_${SESSION_ID}"
EXPIRE_MINUTES=${1:-60}
BORE_PID=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[+]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1" >&2; }
log_error() { echo -e "${RED}[x]${NC} $1" >&2; }

cleanup() {
    log_info "Cleaning up..."
    pkill -f "bore.*${TEMP_USER}" 2>/dev/null || true
    userdel -r "${TEMP_USER}" 2>/dev/null || true
    rm -f "${KEY_PATH}" "${KEY_PATH}.pub" 2>/dev/null || true
    rm -f "/tmp/authorized_keys_${SESSION_ID}" 2>/dev/null || true
    systemctl stop opentunnel.timer 2>/dev/null || true
    systemctl disable opentunnel.timer 2>/dev/null || true
    rm -f /etc/systemd/system/opentunnel.service
    rm -f /etc/systemd/system/opentunnel.timer
    systemctl daemon-reload 2>/dev/null || true
    log_info "Cleanup complete"
}

setup_cleanup_timer() {
    log_info "Setting up auto-cleanup timer for ${EXPIRE_MINUTES} minutes..."
    
    cat > /tmp/opentunnel.service << EOF
[Unit]
Description=OpenTunnel Cleanup

[Service]
Type=oneshot
ExecStart=/bin/bash -c "userdel -r ${TEMP_USER} 2>/dev/null; pkill -f bore 2>/dev/null; rm -f ${KEY_PATH} 2>/dev/null"
EOF

    cat > /tmp/opentunnel.timer << EOF
[Unit]
Description=Auto cleanup after ${EXPIRE_MINUTES} minutes

[Timer]
OnActiveSec=${EXPIRE_MINUTES}min
Unit=opentunnel.service

[Install]
WantedBy=timers.target
EOF

    sudo mv /tmp/opentunnel.service /etc/systemd/system/
    sudo mv /tmp/opentunnel.timer /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable opentunnel.timer
    sudo systemctl start opentunnel.timer
}

install_bore() {
    if command -v bore &> /dev/null; then
        log_info "bore already installed"
        return
    fi
    
    log_info "Installing bore..."
    BORE_VERSION="0.6.0"
    ARCH=$(uname -m)
    
    case $ARCH in
        x86_64) BORE_ARCH="x86_64" ;;
        aarch64) BORE_ARCH="aarch64" ;;
        i686) BORE_ARCH="i686" ;;
        arm*) BORE_ARCH="arm" ;;
        *) 
            if [ "$(uname -o)" = "Android" ]; then
                BORE_ARCH="aarch64"
            else
                log_error "Unsupported architecture: $ARCH"
                exit 1
            fi
            ;;
    esac
    
    TEMP_BORE="/tmp/bore_${SESSION_ID}"
    curl -fsSL "https://github.com/ekzhang/bore/releases/download/v${BORE_VERSION}/bore-v${BORE_VERSION}-${BORE_ARCH}-unknown-linux-musl.tar.gz" | tar -xz -C /tmp
    sudo mv /tmp/bore "$TEMP_BORE"
    sudo mv "$TEMP_BORE" /usr/local/bin/bore
    sudo chmod +x /usr/local/bin/bore
    log_info "bore installed successfully"
}

generate_ssh_key() {
    log_info "Generating SSH key..."
    ssh-keygen -t ed25519 -f "${KEY_PATH}" -N "" -C "opentunnel-${SESSION_ID}" 2>/dev/null
    chmod 600 "${KEY_PATH}"
    log_info "SSH key generated at ${KEY_PATH}"
}

setup_ssh_user() {
    log_info "Setting up temporary SSH user..."
    
    if id "${TEMP_USER}" &>/dev/null; then
        log_warn "User ${TEMP_USER} exists, removing..."
        sudo userdel -r "${TEMP_USER}" 2>/dev/null || true
    fi
    
    sudo useradd -m -s /bin/bash "${TEMP_USER}" 2>/dev/null || true
    
    sudo mkdir -p "/home/${TEMP_USER}/.ssh"
    sudo cp "${KEY_PATH}.pub" "/home/${TEMP_USER}/.ssh/authorized_keys"
    sudo chown -R "${TEMP_USER}:${TEMP_USER}" "/home/${TEMP_USER}/.ssh"
    sudo chmod 700 "/home/${TEMP_USER}/.ssh"
    sudo chmod 600 "/home/${TEMP_USER}/.ssh/authorized_keys"
    
    log_info "User ${TEMP_USER} configured"
}

start_tunnel() {
    log_info "Starting bore tunnel..."
    
    bore local 22 --to bore.pub > /tmp/opentunnel.log 2>&1 &
    BORE_PID=$!
    
    sleep 1
    
    for i in 1 2 3 4 5 6 7 8 9 10; do
        sleep 1
        if [ -f /tmp/opentunnel.log ]; then
            BORE_URL=$(grep -oE 'bore\.pub:[0-9]+' /tmp/opentunnel.log | head -1 | sed 's/bore\.pub://')
            if [ -n "$BORE_URL" ]; then
                break
            fi
        fi
    done
    
    if [ -z "$BORE_URL" ]; then
        log_error "Could not get bore URL after 10 seconds"
        cat /tmp/opentunnel.log
        kill $BORE_PID 2>/dev/null || true
        exit 1
    fi
    
    log_info "Tunnel started successfully"
    echo "$BORE_URL"
}

print_output() {
    local bore_url="$1"
    
    echo ""
    echo "========================================================"
    echo -e "              ${GREEN}OPENTUNNEL READY${NC}"
    echo "========================================================"
    echo ""
    echo "Tunnel: ${bore_url}.bore.pub"
    echo "User:   ${TEMP_USER}"
    echo ""
    echo "Copy and run this on your local machine:"
    echo "------------------------------------------------------------"
    echo -e "${YELLOW}ssh -o StrictHostKeyChecking=no -i ${KEY_PATH} ${TEMP_USER}@${bore_url}.bore.pub${NC}"
    echo "------------------------------------------------------------"
    echo ""
    echo "Key saved at: ${KEY_PATH}"
    echo "Expires in:   ${EXPIRE_MINUTES} minutes"
    echo ""
    echo "To stop tunnel: pkill -f bore"
    echo "========================================================"
    echo ""
}

main() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run as root or with sudo"
        exit 1
    fi
    
    log_info "Starting OpenTunnel (expires in ${EXPIRE_MINUTES} minutes)..."
    
    install_bore
    generate_ssh_key
    setup_ssh_user
    setup_cleanup_timer
    
    BORE_URL=$(start_tunnel)
    
    print_output "$BORE_URL"
    
    log_info "Tunnel is active. Press Ctrl+C to stop (cleanup will run automatically)"
    
    disown $BORE_PID 2>/dev/null || true
    while kill -0 $BORE_PID 2>/dev/null; do
        sleep 5
    done
}

trap cleanup EXIT

main "$@"
