# OpenTunnel

Connect to remote servers behind NAT/firewall using reverse SSH tunnels.

---

# Quick Start (1 minute)

## Step 1: Install on your server

```bash
curl -fsSL https://raw.githubusercontent.com/julianponguta/opentunnel/main/install.sh | sudo bash
```

This adds the `ot` command to your shell.

## Step 2: Run on server

```bash
ot              # 60 min, tunneluser
ot root         # 60 min, root
```

## Step 3: Connect from your PC

The server will show:
```
Tunnel: bore.pub:12345
```

Connect with:
```bash
ssh -i ~/.ssh/id_ed25519 tunneluser@bore.pub -p 12345
```

---

# Commands

```bash
ot              # 60 min, tunneluser
ot root         # 60 min, root (needs SSH key)
ot 30           # 30 min, tunneluser
ot 30 root      # 30 min, root
```

If using root without SSH key configured:
```bash
ot 60 root "ssh-ed25519 AAAA..."
```

---

# Installation Options

## Option 1: One-liner (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/julianponguta/opentunnel/main/install.sh | sudo bash
```

## Option 2: Add to .bashrc manually

```bash
echo 'ot() { curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.sh?v=$(date +%s)" | sudo bash -s -- "${@}"; }' >> ~/.bashrc && source ~/.bashrc
```

## Option 3: Download script

```bash
curl -fsSL -o /usr/local/bin/ot https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.sh
chmod +x /usr/local/bin/ot
sudo ot root
```

---

# How it works

1. **Server runs**: `bore local 22 --to bore.pub` (creates reverse tunnel)
2. **Server shows**: `bore.pub:PORT`
3. **You connect**: `ssh user@bore.pub -p PORT`

---

# Requirements

- Linux server (any distro)
- Root/sudo access
- Outbound HTTPS (port 443)

---

# OpenCode / AI Agents

Install the opentunnel-connect skill and use it by following: https://raw.githubusercontent.com/julianponguta/opentunnel/main/AGENT_SETUP.md
