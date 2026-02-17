# OpenTunnel

Connect to remote servers behind NAT/firewall using reverse SSH tunnels.

---

# Quick Install (Manual Use)

## Install on your server

Add this to your `~/.bashrc`:

```bash
echo 'ot() { curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.sh?v=$(date +%s)" | sudo bash -s -- "${@:-60}"; }' >> ~/.bashrc && source ~/.bashrc
```

## Usage

```bash
# Default: 60 minutes, tunneluser
ot

# 30 minutes, tunneluser
ot 30

# 60 minutes, root
ot 60 root

# With SSH key inline
ot 60 root "ssh-ed25519 AAAA..."

# Or enter SSH key when prompted
ot 60 root
# Then paste your key
```

---

# OpenCode Skill

See `skills/opentunnel-connect/SKILL.md`

---

# Files

- `connect.sh` - Main script for manual use
- `opentunnel.exe` - Windows binary for OpenCode
- `opentunnel.go` - Go source code
- `skills/opentunnel-connect/` - OpenCode skill

---

# How it works

1. **Local**: Get your SSH key
2. **Remote**: Run `ot` command → creates SSH tunnel via bore
3. **Remote**: Shows `bore.pub:PORT`
4. **Local**: Connect to `bore.pub:PORT`
