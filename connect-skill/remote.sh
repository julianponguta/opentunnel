#!/bin/bash

WEBHOOK_URL=""
SESSION_ID=$(openssl rand -hex 4 2>/dev/null || echo "$$")
TEMP_USER="tunneluser"
EXPIRE_MINUTES=60
BORE_PID=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[+]${NC} $1" >&2; }
log_error() { echo -e "${RED}[x]${NC} $1" >&2; }

parse_args() {
    for arg in "$@"; do
        if [[ "$arg" =~ ^[0-9]+$ ]]; then
            EXPIRE_MINUTES=$arg
        elif [[ "$arg" == http* ]]; then
            WEBHOOK_URL=$arg
        else
            TEMP_USER=$arg
        fi
    done
}

generate_password() {
    echo "otp_$(openssl rand -hex 6)"
}

setup_user() {
    if id "${TEMP_USER}" &>/dev/null; then
        log_info "User ${TEMP_USER} exists, using existing password"
        echo "existing"
    else
        PASS=$(generate_password)
        useradd -m -s /bin/bash "${TEMP_USER}"
        echo "${TEMP_USER}:${PASS}" | chpasswd
        echo "$PASS"
    fi
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
    
    curl -fsSL -X POST "${WEBHOOK_URL}/connect" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        || log_error "Failed to send credentials to webhook"
}

cleanup() {
    pkill -f "bore.*${SESSION_ID}" 2>/dev/null || true
    
    if [ -f /tmp/ot_pass ]; then
        if [ "$(cat /tmp/ot_pass)" != "existing" ]; then
            userdel -r "${TEMP_USER}" 2>/dev/null || true
        fi
    fi
}

main() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run as root or with sudo"
        exit 1
    fi
    
    parse_args "$@"
    
    if [ -z "$WEBHOOK_URL" ]; then
        log_error "Webhook URL required. Usage: $0 <webhook_url> [minutes] [user]"
        exit 1
    fi
    
    log_info "Starting OpenTunnel Connect..."
    
    # Install bore if needed
    if ! command -v bore &> /dev/null; then
        log_info "Installing bore..."
        ARCH=$(uname -m)
        case $ARCH in
            x86_64) BORE_ARCH="x86_64" ;;
            aarch64) BORE_ARCH="aarch64" ;;
            *) BORE_ARCH="x86_64" ;;
        esac
        VERSION="0.6.0"
        curl -fsSL "https://github.com/ekzhang/bore/releases/download/v${VERSION}/bore-v${VERSION}-${BORE_ARCH}-unknown-linux-musl.tar.gz" | tar -xz -C /tmp
        mv /tmp/bore /usr/local/bin/bore
        chmod +x /usr/local/bin/bore
    fi
    
    # Setup user
    PASS=$(setup_user)
    echo "$PASS" > /tmp/ot_pass
    
    # Start tunnel
    log_info "Starting bore tunnel..."
    bore local 22 --to bore.pub > /tmp/ot_bore.log 2>&1 &
    BORE_PID=$!
    
    sleep 2
    
    PORT=$(grep -oE 'bore\.pub:[0-9]+' /tmp/ot_bore.log | head -1 | sed 's/bore\.pub://')
    
    if [ -z "$PORT" ]; then
        log_error "Failed to get bore port"
        exit 1
    fi
    
    log_info "Tunnel ready on port ${PORT}"
    
    # Send credentials
    send_credentials "$TEMP_USER" "$PASS" "$PORT"
    
    log_info "Credentials sent. Waiting..."
    
    # Keep running
    wait $BORE_PID
}

trap cleanup EXIT

main "$@"
