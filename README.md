# OpenTunnel

Connect to remote servers behind NAT/firewall using reverse SSH tunnels.

---

# OpenCode / AI Agents

```
Install the opentunnel-connect skill and use it by following: https://raw.githubusercontent.com/julianponguta/opentunnel/main/AGENT_SETUP.md
```

---

# Quick Start

## Install

```bash
echo 'ot() { curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.sh?v=$(date +%s)" | sudo bash -s -- "${@}"; }' >> ~/.bashrc && source ~/.bashrc
```

## Run

```bash
ot              # 60 min, tunneluser
ot root         # 60 min, root
```

## Connect

The server shows:
```
Tunnel: bore.pub:12345
```

Connect:
```bash
ssh -i ~/.ssh/id_ed25519 tunneluser@bore.pub -p 12345
```

---

# Commands

```bash
ot              # 60 min, tunneluser
ot root         # 60 min, root
ot 30           # 30 min, tunneluser
ot 30 root      # 30 min, root
```

With SSH key:
```bash
ot 60 root "ssh-ed25519 AAAA..."
```

---

# How it works

1. **Server runs**: `bore local 22 --to bore.pub`
2. **Server shows**: `bore.pub:PORT`
3. **You connect**: `ssh user@bore.pub -p PORT`

---

# Requirements

- Linux server
- Root/sudo access
- Outbound HTTPS (port 443)
