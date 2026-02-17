# OpenTunnel Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a single bash script that auto-installs bore, generates SSH credentials, starts tunnel, and handles cleanup.

**Architecture:** Single `connect.sh` script that does everything: download bore, create SSH key, configure SSH, start tunnel, schedule cleanup.

**Tech Stack:** Bash, SSH, bore, systemd (for cleanup timer)

---

## Task 1: Create directory structure

**Files:**
- Create: `C:\Users\Julian\Documents\opentunnel\connect.sh`

**Step 1: Create the directory**

Run: `mkdir -p C:\Users\Julian\Documents\opentunnel\docs\plans`

---

## Task 2: Write connect.sh main script

**Files:**
- Create: `connect.sh`

**Step 1: Write the complete connect.sh script**

```bash
#!/bin/bash
set -e

# Configuration
SESSION_ID=$(openssl rand -hex 4)
TEMP_USER="tunneluser"
KEY_PATH="/tmp/opentunnel_key_${SESSION_ID}"
EXPIRE_HOURS=1

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[+]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[x]${NC} $1"; }

cleanup() {
    log_info "Cleaning up..."
    pkill -f "bore.*${TEMP_USER}" 2>/dev/null || true
    userdel -r "${TEMP_USER}" 2>/dev/null || true
    rm -f "${KEY_PATH}" 2>/dev/null || true
    rm -f "/tmp/authorized_keys_${SESSION_ID}" 2>/dev/null || true
    systemctl stop opentunnel.timer 2>/dev/null || true
    systemctl disable opentunnel.timer 2>/dev/null || true
    rm -f /etc/systemd/system/opentunnel.service
    rm -f /etc/systemd/system/opentunnel.timer
    systemctl daemon-reload
    log_info "Cleanup complete"
}

setup_cleanup_timer() {
    log_info "Setting up auto-cleanup timer..."
    
    cat > /etc/systemd/system/opentunnel.service << EOF
[Unit]
Description=OpenTunnel Cleanup

[Service]
Type=oneshot
ExecStart=/bin/bash -c "userdel -r ${TEMP_USER} 2>/dev/null; pkill -f bore 2>/dev/null; rm -f ${KEY_PATH} 2>/dev/null"
EOF

    cat > /etc/systemd/system/opentunnel.timer << EOF
[Unit]
Description=Auto cleanup after ${EXPIRE_HOURS} hour

[Timer]
OnActiveSec=${EXPIRE_HOURS}h
Unit=opentunnel.service

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable opentunnel.timer
    systemctl start opentunnel.timer
}

install_bore() {
    if command -v bore &> /dev/null; then
        log_info "bore already installed"
        return
    fi
    
    log_info "Installing bore..."
    BORE_VERSION="0.4.0"
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) BORE_ARCH="x86_64" ;;
        aarch64) BORE_ARCH="aarch64" ;;
        armv7l) BORE_ARCH="armv7" ;;
        *) log_error "Unsupported architecture: $ARCH"; exit 1 ;;
    esac
    
    curl -fsSL "https://github.com/ekzhang/bore/releases/download/v${BORE_VERSION}/bore-v${BORE_VERSION}-unknown-linux-${BORE_ARCH}.tar.gz" | tar -xz -C /tmp
    sudo mv /tmp/bore /usr/local/bin/bore
    sudo chmod +x /usr/local/bin/bore
    log_info "bore installed successfully"
}

generate_ssh_key() {
    log_info "Generating SSH key..."
    ssh-keygen -t ed25519 -f "${KEY_PATH}" -N "" -C "opentunnel-${SESSION_ID}"
    chmod 600 "${KEY_PATH}"
    log_info "SSH key generated at ${KEY_PATH}"
}

setup_ssh_user() {
    log_info "Setting up temporary SSH user..."
    
    if id "${TEMP_USER}" &>/dev/null; then
        log_warn "User ${TEMP_USER} exists, removing..."
        userdel -r "${TEMP_USER}" 2>/dev/null || true
    fi
    
    sudo useradd -m -s /bin/bash "${TEMP_USER}"
    
    mkdir -p "/home/${TEMP_USER}/.ssh"
    cp "${KEY_PATH}.pub" "/home/${TEMP_USER}/.ssh/authorized_keys"
    chown -R "${TEMP_USER}:${TEMP_USER}" "/home/${TEMP_USER}/.ssh"
    chmod 700 "/home/${TEMP_USER}/.ssh"
    chmod 600 "/home/${TEMP_USER}/.ssh/authorized_keys"
    
    log_info "User ${TEMP_USER} configured"
}

start_tunnel() {
    log_info "Starting bore tunnel..."
    
    nohup bore local 22 --to bore.pub > /tmp/opentunnel.log 2>&1 &
    BORE_PID=$!
    
    sleep 3
    
    if ! kill -0 $BORE_PID 2>/dev/null; then
        log_error "Failed to start bore tunnel"
        cat /tmp/opentunnel.log
        exit 1
    fi
    
    BORE_URL=$(grep -oP '\d+\.bore\.pub' /tmp/opentunnel.log | head -1)
    
    if [ -z "$BORE_URL" ]; then
        log_error "Could not get bore URL"
        cat /tmp/opentunnel.log
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
    echo "Tunnel: ${bore_url}"
    echo "User:   ${TEMP_USER}"
    echo ""
    echo "Copy and run this on your local machine:"
    echo "------------------------------------------------------------"
    echo -e "${YELLOW}ssh -o StrictHostKeyChecking=no -i ${KEY_PATH} ${TEMP_USER}@${bore_url}${NC}"
    echo "------------------------------------------------------------"
    echo ""
    echo "Key saved at: ${KEY_PATH}"
    echo "Expires in:   ${EXPIRE_HOURS} hour(s)"
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
    
    log_info "Starting OpenTunnel..."
    
    install_bore
    generate_ssh_key
    setup_ssh_user
    setup_cleanup_timer
    
    BORE_URL=$(start_tunnel)
    
    print_output "$BORE_URL"
    
    log_info "Tunnel is active. Press Ctrl+C to stop (cleanup will run automatically)"
    
    wait
}

trap cleanup EXIT

main "$@"
```

**Step 2: Make it executable**

Run: `chmod +x connect.sh`

---

## Task 3: Verify script works locally (optional)

**Step 1: Test syntax**

Run: `bash -n connect.sh`

Expected: No output (no syntax errors)

---

## Task 4: Create simple README

**Files:**
- Create: `README.md`

```markdown
# OpenTunnel

One-command SSH tunnel to access remote servers.

## Usage

On your remote server, run:

```bash
curl -fsSL https://get.opentunnel.dev | sudo bash
```

Or save and run locally:

```bash
curl -fsSL https://get.opentunnel.dev -o connect.sh
chmod +x connect.sh
sudo ./connect.sh
```

## What it does

1. Installs bore (if not present)
2. Generates temporary SSH key
3. Creates temporary user
4. Starts tunnel to bore.pub
5. Sets auto-cleanup timer (1 hour)

## Output

You'll get a command like:

```bash
ssh -o StrictHostKeyChecking=no -i /tmp/opentunnel_key_abc123 tunneluser@12345.bore.pub
```

Run this on your local machine to connect.

## Security

- Key auto-expires after 1 hour
- User and key are deleted automatically
- No persistent access
```

---

## Task 5: Commit changes

**Step 1: Initialize git and commit**

Run:
```bash
git init
git add .
git commit -m "feat: initial opentunnel project"
```

---

## Plan Complete

Tasks:
1. ✅ Create directory structure
2. ⏳ Write connect.sh script
3. ⏳ Verify script syntax
4. ⏳ Create README
5. ⏳ Commit

**Two execution options:**

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

**Which approach?**
