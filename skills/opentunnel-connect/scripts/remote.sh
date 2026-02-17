#!/bin/bash

WEBHOOK_URL=""
SESSION_ID=$(openssl rand -hex 4 2>/dev/null || date +%s)
TEMP_USER="tunneluser"
EXPIRE_MINUTES=60
BORE_PID=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[+]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1" >&2; }
log_error() { echo -e "${RED}[x]${NC} $1" >&2; }

usage() {
    echo "Usage: $0 <webhook_url> [minutes] [username]"
    echo ""
    echo "Arguments:"
    echo "  webhook_url  The localhost.run URL from local machine (e.g., xxx.lhr.life)"
    echo "  minutes     Minutes until auto-disconnect (default: 60)"
    echo "  username    SSH user to create (default: tunneluser)"
    echo ""
    echo "Example:"
    echo "  $0 xxx.lhr.life 60 root"
    exit 1
}

parse_args() {
    if [ $# -lt 1 ]; then
        usage
    fi
    
    WEBHOOK_URL="$1"
    
    if [[ "$2" =~ ^[0-9]+$ ]]; then
        EXPIRE_MINUTES=$2
    fi
    
    if [ -n "$3" ]; then
        TEMP_USER="$3"
    fi
}

generate_password() {
    echo "otp_$(openssl rand -hex 6 2>/dev/null || head -c 12 /dev/urandom | xxd -p)"
}

setup_user() {
    if id "${TEMP_USER}" &>/dev/null; then
        log_info "User ${TEMP_USER} already exists"
        echo "existing"
        return 0
    fi
    
    local PASS=$(generate_password)
    
    if useradd -m -s /bin/bash "${TEMP_USER}" 2>/dev/null; then
        echo "${TEMP_USER}:${PASS}" | chpasswd
        log_info "Created user ${TEMP_USER}"
        echo "$PASS"
    else
        log_error "Failed to create user"
        return 1
    fi
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

wait_for_bore() {
    for i in $(seq 1 30); do
        if [ -f /tmp/ot_bore.log ]; then
            PORT=$(grep -oE 'bore\.pub:[0-9]+' /tmp/ot_bore.log | head -1 | sed 's/bore\.pub://')
            if [ -n "$PORT" ]; then
                return 0
            fi
        fi
        sleep 1
    done
    return 1
}

start_tunnel() {
    log_info "Starting bore tunnel..."
    
    bore local 22 --to bore.pub > /tmp/ot_bore.log 2>&1 &
    BORE_PID=$!
    
    if ! wait_for_bore; then
        log_error "Failed to establish tunnel"
        cat /tmp/ot_bore.log
        return 1
    fi
    
    PORT=$(grep -oE 'bore\.pub:[0-9]+' /tmp/ot_bore.log | sed 's/bore\.pub://')
    log_info "Tunnel ready on port ${PORT}"
    echo "$PORT"
}

send_credentials() {
    local user=$1
    local pass=$2
    local port=$3
    
    local payload=$(cat <<EOF
{
    "user": "${user}",
    "password": "${pass}",
    "host": "bore.pub",
    "port": ${port}
}
EOF
)
    
    log_info "Sending credentials to webhook..."
    
    for i in 1 2 3; do
        if curl -fsSL -X POST "http://${WEBHOOK_URL}/connect" \
            -H "Content-Type: application/json" \
            -d "$payload" 2>/dev/null; then
            log_info "Credentials sent!"
            return 0
        fi
        log_warn "Retrying..."
        sleep 2
    done
    
    log_error "Failed to send credentials"
    return 1
}

cleanup() {
    log_info "Cleaning up..."
    
    if [ -n "$BORE_PID" ]; then
        kill $BORE_PID 2>/dev/null || true
    fi
    
    pkill -f "bore.*${SESSION_ID}" 2>/dev/null || true
    
    if [ -f /tmp/ot_pass ]; then
        if [ "$(cat /tmp/ot_pass)" != "existing" ]; then
            userdel -r "${TEMP_USER}" 2>/dev/null || true
        fi
    fi
    
    rm -f /tmp/ot_pass /tmp/ot_bore.log
}

main() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run as root or with sudo"
        exit 1
    fi
    
    parse_args "$@"
    
    log_info "Starting OpenTunnel Connect..."
    log_info "Webhook: ${WEBHOOK_URL}"
    log_info "User: ${TEMP_USER}"
    
    if ! install_bore; then
        log_error "Failed to install bore"
        exit 1
    fi
    
    PASS=$(setup_user) || exit 1
    echo "$PASS" > /tmp/ot_pass
    
    PORT=$(start_tunnel) || exit 1
    
    send_credentials "$TEMP_USER" "$PASS" "$PORT"
    
    echo ""
    echo "========================================================"
    echo -e "              ${GREEN}CONNECTED${NC}"
    echo "========================================================"
    echo ""
    echo "Tunnel: bore.pub:${PORT}"
    echo "User: ${TEMP_USER}"
    echo "Webhook: ${WEBHOOK_URL}"
    echo ""
    echo "Auto-disconnecting in ${EXPIRE_MINUTES} minutes"
    echo "========================================================"
    echo ""
    
    sleep $((EXPIRE_MINUTES * 60))
}

trap cleanup EXIT INT TERM

main "$@"
