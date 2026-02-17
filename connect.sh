#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

SESSION_ID=$(openssl rand -hex 4 2>/dev/null || date +%s)

if [[ "$1" =~ ^[0-9]+$ ]]; then
    EXPIRE_MINUTES=$1
    TEMP_USER=${2:-tunneluser}
    WEBHOOK_URL=${3:-}
else
    TEMP_USER=${1:-tunneluser}
    EXPIRE_MINUTES=${2:-60}
    WEBHOOK_URL=${3:-}
fi

cleanup() {
    echo "[*] Cleaning up..."
    pkill -f "bore.*${SESSION_ID}" 2>/dev/null || true
    pkill -f "localhost.run" 2>/dev/null || true
    
    if [ -f /tmp/ot_pass ]; then
        if [ "$(cat /tmp/ot_pass)" != "existing" ]; then
            userdel -r "${TEMP_USER}" 2>/dev/null || true
        fi
    fi
    
    rm -f /tmp/ot_pass /tmp/ot_url /tmp/ot_bore.log
    echo "[*] Cleanup complete"
}

setup_user() {
    echo "[*] Setting up SSH user: ${TEMP_USER}"
    
    if id "${TEMP_USER}" &>/dev/null; then
        echo "[*] User ${TEMP_USER} exists"
        echo "existing" > /tmp/ot_pass
    else
        PASS="otp_$(openssl rand -hex 6)"
        useradd -m -s /bin/bash "${TEMP_USER}"
        echo "${TEMP_USER}:${PASS}" | chpasswd
        echo "$PASS" > /tmp/ot_pass
        echo "[*] Created user ${TEMP_USER} with temp password"
    fi
}

setup_timer() {
    echo "[*] Setting up cleanup timer for ${EXPIRE_MINUTES} minutes..."
    
    if command -v systemctl &> /dev/null; then
        cat > /tmp/ot-cleanup.service << EOF
[Unit]
Description=OpenTunnel Cleanup

[Service]
Type=oneshot
ExecStart=/bin/bash -c "userdel -r ${TEMP_USER} 2>/dev/null; pkill -f bore 2>/dev/null; pkill -f localhost.run 2>/dev/null"
EOF

        cat > /tmp/ot-cleanup.timer << EOF
[Unit]
Description=Auto cleanup after ${EXPIRE_MINUTES} minutes

[Timer]
OnActiveSec=${EXPIRE_MINUTES}min
Unit=ot-cleanup.service

[Install]
WantedBy=timers.target
EOF

        mv /tmp/ot-cleanup.service /etc/systemd/system/
        mv /tmp/ot-cleanup.timer /etc/systemd/system/
        systemctl daemon-reload
        systemctl enable ot-cleanup.timer
        systemctl start ot-cleanup.timer
    fi
}

install_bore() {
    if command -v bore &> /dev/null; then
        return 0
    fi
    
    echo "[*] Installing bore..."
    
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
        echo "[*] bore installed"
        return 0
    fi
    
    echo "[!] Failed to install bore"
    return 1
}

start_bore_tunnel() {
    echo "[*] Starting bore tunnel..."
    
    bore local 22 --to bore.pub > /tmp/ot_bore.log 2>&1 &
    
    for i in $(seq 1 30); do
        PORT=$(grep -oE 'bore\.pub:[0-9]+' /tmp/ot_bore.log | head -1 | sed 's/bore\.pub://')
        if [ -n "$PORT" ]; then
            echo "[*] Tunnel ready on bore.pub:${PORT}"
            return 0
        fi
        sleep 1
    done
    
    return 1
}

send_credentials() {
    local user=$1
    local pass=$2
    local port=$3
    local webhook=$4
    
    if [ -z "$webhook" ]; then
        echo "[*] No webhook URL provided, skipping..."
        return 0
    fi
    
    echo "[*] Sending credentials to webhook..."
    
    local payload=$(cat <<EOF
{
    "user": "${user}",
    "password": "${pass}",
    "host": "bore.pub",
    "port": ${port}
}
EOF
)
    
    for i in 1 2 3; do
        if curl -fsSL -X POST "http://${webhook}/connect" \
            -H "Content-Type: application/json" \
            -d "$payload" 2>/dev/null; then
            echo "[*] Credentials sent!"
            return 0
        fi
        sleep 2
    done
    
    echo "[!] Failed to send credentials"
    return 1
}

print_info() {
    local port=$(grep -oE 'bore\.pub:[0-9]+' /tmp/ot_bore.log | sed 's/bore\.pub://')
    local pass=$(cat /tmp/ot_pass)
    
    echo ""
    echo "========================================================"
    echo "              OPENTUNNEL READY"
    echo "========================================================"
    echo ""
    echo "Host: bore.pub"
    echo "Port: ${port}"
    echo "User: ${TEMP_USER}"
    
    if [ "$pass" = "existing" ]; then
        echo "Password: (your existing password)"
    else
        echo "Password: ${pass}"
    fi
    
    echo ""
    echo "Connect with:"
    echo "------------------------------------------------------------"
    echo "ssh -p ${port} ${TEMP_USER}@bore.pub"
    echo "------------------------------------------------------------"
    echo ""
    echo "Expires in: ${EXPIRE_MINUTES} minutes"
    echo "========================================================"
    echo ""
}

main() {
    echo "[*] Starting OpenTunnel..."
    
    if ! install_bore; then
        echo "[!] Cannot proceed without bore"
        exit 1
    fi
    
    setup_user
    setup_timer
    
    if ! start_bore_tunnel; then
        echo "[!] Failed to establish tunnel"
        cat /tmp/ot_bore.log
        exit 1
    fi
    
    PORT=$(grep -oE 'bore\.pub:[0-9]+' /tmp/ot_bore.log | sed 's/bore\.pub://')
    
    PASS=$(cat /tmp/ot_pass)
    
    if [ -n "$WEBHOOK_URL" ]; then
        send_credentials "$TEMP_USER" "$PASS" "$PORT" "$WEBHOOK_URL"
    fi
    
    print_info
    
    echo "[*] Tunnel active. Will auto-cleanup in ${EXPIRE_MINUTES} minutes"
    
    wait
}

trap cleanup EXIT INT TERM

main
