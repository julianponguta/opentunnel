# OpenTunnel

Connect to remote servers behind NAT/firewall using reverse SSH tunnels.

---

## OpenCode / AI Agents

Let AI agents control remote servers through SSH tunnels.

```bash
# OpenCode
npx skills add julianponguta/opentunnel/skills/opentunnel-connect

# Global (any agent)
npx skills add julianponguta/opentunnel/skills/opentunnel-connect --global
```

See [AGENT_SETUP.md](AGENT_SETUP.md) for full setup.

---

## Quick Start

### Install

```bash
echo 'ot() { curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.sh?v=$(date +%s)" | sudo bash -s -- "${@}"; }' >> ~/.bashrc && source ~/.bashrc
```

---

## Two Ways to Connect

### Option A: Password (Simplest)

Run on the remote server:
```bash
ot                    # creates tunneluser with temp password
```

Server outputs:
```
Tunnel: bore.pub:12345
User: tunneluser
Password: abc123xyz789
```

Connect from your machine:
```bash
ssh tunneluser@bore.pub -p 12345
# Enter password shown above
```

---

### Option B: SSH Key (Recommended)

1. Get your public key (on your local machine):
   ```bash
   cat ~/.ssh/id_ed25519.pub
   # or
   cat ~/.ssh/id_rsa.pub
   ```

2. Run on the remote server with your key:
   ```bash
   ot root "ssh-ed25519 AAAA... your@email.com"
   ```

3. Server outputs:
   ```
   Tunnel: bore.pub:12345
   User: root
   ```

4. Connect from your machine:
   ```bash
   ssh -i ~/.ssh/id_ed25519 root@bore.pub -p 12345
   ```

---

## Commands

| Command | Duration | User | Auth |
|---------|----------|------|------|
| `ot` | 60 min | tunneluser | temp password |
| `ot root` | 60 min | root | existing password |
| `ot 30` | 30 min | tunneluser | temp password |
| `ot 30 root` | 30 min | root | existing password |
| `ot 60 root "ssh-key..."` | 60 min | root | SSH key |

---

## How it Works

1. **Server**: Creates reverse tunnel via bore.pub
2. **Output**: Shows `bore.pub:PORT` + credentials
3. **You**: Connect via `ssh user@bore.pub -p PORT`

---

## Requirements

- Linux server
- Root/sudo access
- Outbound HTTPS (port 443)
