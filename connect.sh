#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

SESSION_ID=$(openssl rand -hex 4 2>/dev/null || date +%s)
TEMP_USER=${1:-tunneluser}
EXPIRE_MINUTES=${2:-60}
SSH_PROCESS=""

cleanup() {
    echo "[*] Cleaning up..."
    
    if [ -n "$SSH_PROCESS" ]; then
        kill $SSH_PROCESS 2>/dev/null || true
    fi
    
    pkill -f "localhost.run" 2>/dev/null || true
    
    if [ -f /tmp/ot_pass ]; then
        if [ "$(cat /tmp/ot_pass)" != "existing" ]; then
            userdel -r "${TEMP_USER}" 2>/dev/null || true
        fi
    fi
    
    rm -f /tmp/ot_pass /tmp/ot_url
    
    echo "[*] Cleanup complete"
}

setup_timer() {
    echo "[*] Setting up cleanup timer for ${EXPIRE_MINUTES} minutes..."
    
    if command -v systemctl &> /dev/null; then
        cat > /tmp/ot-cleanup.service << EOF
[Unit]
Description=OpenTunnel Cleanup

[Service]
Type=oneshot
ExecStart=/bin/bash -c "userdel -r ${TEMP_USER} 2>/dev/null; pkill -f localhost.run 2>/dev/null"
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

        sudo mv /tmp/ot-cleanup.service /etc/systemd/system/
        sudo mv /tmp/ot-cleanup.timer /etc/systemd/system/
        sudo systemctl daemon-reload
        sudo systemctl enable ot-cleanup.timer
        sudo systemctl start ot-cleanup.timer
    fi
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

start_tunnel() {
    echo "[*] Starting localhost.run tunnel..."
    
    ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=60 -R 80:localhost:22 localhost.run 2>&1 | tee /tmp/ot_url &
    SSH_PROCESS=$!
    
    sleep 5
    
    for i in $(seq 1 20); do
        URL=$(grep -oE '[a-zA-Z0-9.-]+\.lhr\.life' /tmp/ot_url | head -1)
        if [ -n "$URL" ]; then
            echo "$URL" > /tmp/ot_url
            return 0
        fi
        sleep 1
    done
    
    return 1
}

print_info() {
    local url=$(cat /tmp/ot_url)
    local pass=$(cat /tmp/ot_pass)
    
    echo ""
    echo "========================================================"
    echo "              OPENTUNNEL READY"
    echo "========================================================"
    echo ""
    echo "URL: $url"
    echo "User: ${TEMP_USER}"
    
    if [ "$pass" = "existing" ]; then
        echo "Password: (your existing password)"
    else
        echo "Password: ${pass}"
    fi
    
    echo ""
    echo "Connect with:"
    echo "------------------------------------------------------------"
    echo "ssh -p 22 ${TEMP_USER}@${url}"
    echo "------------------------------------------------------------"
    echo ""
    echo "Expires in: ${EXPIRE_MINUTES} minutes"
    echo "========================================================"
    echo ""
}

main() {
    echo "[*] Starting OpenTunnel (expires in ${EXPIRE_MINUTES} minutes)..."
    
    setup_user
    setup_timer
    
    if ! start_tunnel; then
        echo "[x] Failed to establish tunnel"
        cat /tmp/ot_url
        exit 1
    fi
    
    print_info
    
    echo "[*] Tunnel active. Will auto-cleanup in ${EXPIRE_MINUTES} minutes"
    
    wait $SSH_PROCESS
}

trap cleanup EXIT INT TERM

main
