#!/bin/bash

SESSION_ID=$(openssl rand -hex 4 2>/dev/null || echo "$$")
BORE_PID=""

if [[ "$1" =~ ^[0-9]+$ ]]; then
    EXPIRE_MINUTES=$1
    TEMP_USER=${2:-tunneluser}
else
    EXPIRE_MINUTES=${2:-60}
    TEMP_USER=${1:-tunneluser}
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[+]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1" >&2; }
log_error() { echo -e "${RED}[x]${NC} $1" >&2; }

cleanup() {
    log_info "Cleaning up..."
    pkill -f "bore.*${SESSION_ID}" 2>/dev/null || true
    
    if [ -f /tmp/opentunnel_pass ]; then
        if [ "$(cat /tmp/opentunnel_pass)" != "existing" ]; then
            userdel -r "${TEMP_USER}" 2>/dev/null || true
        fi
    fi
    
    systemctl stop opentunnel.timer 2>/dev/null || true
    systemctl disable opentunnel.timer 2>/dev/null || true
    rm -f /etc/systemd/system/opentunnel.service
    rm -f /etc/systemd/system/opentunnel.timer
    systemctl daemon-reload 2>/dev/null || true
    log_info "Cleanup complete"
}

setup_cleanup_timer() {
    log_info "Setting up auto-cleanup timer for ${EXPIRE_MINUTES} minutes..."
    
    if [ "$(cat /tmp/opentunnel_pass)" = "existing" ]; then
        CLEANUP_CMD="pkill -f bore 2>/dev/null"
    else
        CLEANUP_CMD="userdel -r ${TEMP_USER} 2>/dev/null; pkill -f bore 2>/dev/null"
    fi
    
    cat > /tmp/opentunnel.service << EOF
[Unit]
Description=OpenTunnel Cleanup

[Service]
Type=oneshot
ExecStart=/bin/bash -c "${CLEANUP_CMD}"
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

generate_password() {
    TEMP_PASS="otp_$(openssl rand -hex 6)"
    echo "$TEMP_PASS"
}

setup_ssh_user() {
    log_info "Setting up SSH for user: ${TEMP_USER}"
    
    if id "${TEMP_USER}" &>/dev/null; then
        log_info "User ${TEMP_USER} exists, using existing password"
        echo "existing" > /tmp/opentunnel_pass
    else
        TEMP_PASS=$(generate_password)
        sudo useradd -m -s /bin/bash "${TEMP_USER}"
        echo "${TEMP_USER}:${TEMP_PASS}" | sudo chpasswd
        echo "$TEMP_PASS" > /tmp/opentunnel_pass
    fi
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
    local password=$(cat /tmp/opentunnel_pass)
    
    echo ""
    echo "========================================================"
    echo -e "              ${GREEN}OPENTUNNEL READY${NC}"
    echo "========================================================"
    echo ""
    echo "User: ${TEMP_USER}"
    
    if [ "$password" = "existing" ]; then
        echo "Password: (your existing password)"
    else
        echo "Password: ${password}"
    fi
    
    echo ""
    echo "Connect with:"
    echo "------------------------------------------------------------"
    echo -e "${YELLOW}ssh -p ${bore_url} ${TEMP_USER}@bore.pub${NC}"
    echo "------------------------------------------------------------"
    echo ""
    echo "Expires in: ${EXPIRE_MINUTES} minutes"
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
    setup_ssh_user
    setup_cleanup_timer
    
    BORE_URL=$(start_tunnel)
    
    print_output "$BORE_URL"
    
    log_info "Tunnel is active. Timer will auto-cleanup in ${EXPIRE_MINUTES} minutes"
    
    nohup bore local 22 --to bore.pub > /dev/null 2>&1 &
    sleep 1
    
    exit 0
}

main "$@"
