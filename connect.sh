#!/bin/bash

# OpenTunnel - SSH via Pinggy TCP tunnel
# Sin instalar nada (usa el ssh del sistema), sin cuenta, sin email.
# Usage: ot [minutes] [username] [ssh_key]
# Examples:
#   ot              # 60 min, tunneluser
#   ot root         # 60 min, root
#   ot 60           # 60 min, tunneluser
#   ot 60 root      # 60 min, root
#
# NOTA: la llave SSH que se pase debe ir SIN comentario/email.
# Solo se usan los 2 primeros campos: "ssh-ed25519 AAAA..."

SESSION_ID=$(openssl rand -hex 4 2>/dev/null || date +%s)
TEMP_USER="tunneluser"
EXPIRE_MINUTES=60
SSH_PID=""
SSH_KEY=""
TEMP_PASSWORD=""

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[+]${NC} $1" >&2; }
log_error() { echo -e "${RED}[x]${NC} $1" >&2; }

# Parse arguments - flexible format
for arg in "$@"; do
    if [[ "$arg" =~ ^ssh- ]]; then
        # Sanitizar: solo tipo + base64, sin comentario/email
        SSH_KEY=$(echo "$arg" | awk '{print $1" "$2}')
    elif [[ "$arg" =~ ^[0-9]+$ ]]; then
        EXPIRE_MINUTES="$arg"
    elif [ -n "$arg" ]; then
        TEMP_USER="$arg"
    fi
done

# For root: use existing password
# For other users: create temp password if no SSH key
if [ -z "$SSH_KEY" ]; then
    if [ "$TEMP_USER" = "root" ]; then
        log_info "No SSH key provided - use existing root password"
    else
        TEMP_PASS=$(openssl rand -base64 12 2>/dev/null | tr -dc 'a-zA-Z0-9' | head -c 16)
        useradd -m -s /bin/bash "$TEMP_USER" 2>/dev/null || true
        echo "$TEMP_USER:$TEMP_PASS" | chpasswd
        TEMP_PASSWORD="$TEMP_PASS"
        log_info "Created temporary user ${TEMP_USER} with password"
    fi
fi

setup_user_with_key() {
    local user=$1
    local key=$2

    if [ -z "$key" ]; then
        return 0
    fi

    if [ "$user" = "root" ]; then
        HOME_DIR="/root"
    else
        HOME_DIR="/home/${user}"
        id "$user" &>/dev/null || useradd -m -s /bin/bash "$user"
    fi

    mkdir -p "${HOME_DIR}/.ssh"
    chmod 700 "${HOME_DIR}/.ssh"

    if ! grep -qF "$key" "${HOME_DIR}/.ssh/authorized_keys" 2>/dev/null; then
        echo "$key" >> "${HOME_DIR}/.ssh/authorized_keys"
    fi
    chmod 600 "${HOME_DIR}/.ssh/authorized_keys"
    if [ "$user" != "root" ]; then
        chown -R "${user}:${user}" "${HOME_DIR}/.ssh"
    fi

    log_info "SSH key added for user ${user}"
}

ensure_sshd() {
    # Ya escuchando en 22?
    if (command -v ss &>/dev/null && ss -ltn 2>/dev/null | grep -q ':22 ') || \
       (command -v netstat &>/dev/null && netstat -ltn 2>/dev/null | grep -q ':22 '); then
        return 0
    fi

    log_info "Starting SSH server..."

    if ! command -v sshd &>/dev/null; then
        if command -v apt-get &>/dev/null; then
            apt-get update -qq && apt-get install -y -qq openssh-server
        elif command -v dnf &>/dev/null; then
            dnf install -y -q openssh-server
        elif command -v apk &>/dev/null; then
            apk add --no-cache openssh-server openssh-client
            ssh-keygen -A
        fi
    fi

    mkdir -p /run/sshd
    # Permitir login con password para modo sin llave
    if [ -z "$SSH_KEY" ]; then
        sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null || \
            echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
    fi

    service ssh start 2>/dev/null || service sshd start 2>/dev/null || /usr/sbin/sshd 2>/dev/null || true
}

ensure_ssh_client() {
    if command -v ssh &>/dev/null; then
        return 0
    fi

    log_info "Installing OpenSSH client..."
    if command -v apt-get &>/dev/null; then
        apt-get update -qq && apt-get install -y -qq openssh-client
    elif command -v dnf &>/dev/null; then
        dnf install -y -q openssh-clients
    elif command -v apk &>/dev/null; then
        apk add --no-cache openssh-client
    fi

    command -v ssh &>/dev/null
}

# Endpoints a probar en orden (el free a veces falla segun PoP/red)
PINGGY_ENDPOINTS="tcp@free.pinggy.io tcp@a.pinggy.io"

start_tunnel() {
    log_info "Opening TCP tunnel via Pinggy (solo ssh, sin instalar nada)..."

    for ENDPOINT in $PINGGY_ENDPOINTS; do
        log_info "Trying ${ENDPOINT} ..."
        rm -f /tmp/ot_pinggy.log
        # tcp@... no pide auth. BatchMode evita que se cuelgue
        # preguntando password si el servidor alguna vez lo pidiera.
        # IMPORTANTE: sin -N. Pinggy anuncia la URL tcp:// por el canal de
        # shell; con -N nunca la imprime y el parseo falla. -n desacopla stdin.
        bash -c "ssh -nT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o ConnectTimeout=15 -o BatchMode=yes -o LogLevel=ERROR -p 443 -R0:localhost:22 ${ENDPOINT} 2>&1" > /tmp/ot_pinggy.log &
        SSH_PID=$!

        for i in $(seq 1 20); do
            if [ -s /tmp/ot_pinggy.log ]; then
                TUNNEL=$(grep -oE 'tcp://[A-Za-z0-9.-]+:[0-9]+' /tmp/ot_pinggy.log | head -1 | sed 's|tcp://||')
                if [ -n "$TUNNEL" ]; then
                    log_info "Tunnel ready via ${ENDPOINT}: ${TUNNEL}"
                    echo "$TUNNEL"
                    return 0
                fi
            fi
            # Si ssh murio, pasar al siguiente endpoint
            if ! kill -0 $SSH_PID 2>/dev/null; then
                break
            fi
            sleep 1
        done

        kill $SSH_PID 2>/dev/null
        wait $SSH_PID 2>/dev/null
        SSH_PID=""
        log_error "No URL from ${ENDPOINT}, probando siguiente..."
    done

    log_error "Failed to establish tunnel (todos los endpoints fallaron)"
    cat /tmp/ot_pinggy.log >&2
    return 1
}

cleanup() {
    [ -n "$SSH_PID" ] && kill $SSH_PID 2>/dev/null
    rm -f /tmp/ot_pinggy.log
}

# Main
if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root or with sudo"
    exit 1
fi

# SSH primero (el tunel necesita algo escuchando en 22)
ensure_sshd

log_info "OpenTunnel v7.2 - ${EXPIRE_MINUTES} min, user: ${TEMP_USER}"

if ! ensure_ssh_client; then
    log_error "Failed to install OpenSSH client"
    exit 1
fi

setup_user_with_key "$TEMP_USER" "$SSH_KEY"

TUNNEL=$(start_tunnel) || exit 1
HOST=$(echo "$TUNNEL" | cut -d: -f1)
PORT=$(echo "$TUNNEL" | cut -d: -f2)

echo ""
echo "========================================================"
echo -e "              ${GREEN}CONNECTED${NC}"
echo "========================================================"
echo ""
echo "Tunnel: ${TUNNEL}"
echo "User: ${TEMP_USER}"
if [ -n "$TEMP_PASSWORD" ]; then
    echo "Password: ${TEMP_PASSWORD}"
fi
if [ "$TEMP_USER" = "root" ] && [ -z "$SSH_KEY" ]; then
    echo "Password: (use your existing root password)"
fi
echo ""
echo "COPY TO YOUR LOCAL MACHINE:"
echo "  ${TUNNEL}"
echo ""
echo "CONNECT FROM LOCAL (plain ssh, nada que instalar):"
if [ -n "$SSH_KEY" ]; then
    echo "  ssh -i ~/.ssh/id_ed25519 -p ${PORT} ${TEMP_USER}@${HOST}"
else
    echo "  ssh -p ${PORT} ${TEMP_USER}@${HOST}"
fi
echo ""
echo "========================================================"

trap cleanup EXIT INT TERM

sleep $((EXPIRE_MINUTES * 60))
