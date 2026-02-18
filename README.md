# OpenTunnel

Connect to remote servers behind NAT using reverse SSH tunnels.

---

# Quick Install

```bash
echo 'ot() { curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.sh?v=$(date +%s)" | sudo bash -s -- "${@}"; }' >> ~/.bashrc && source ~/.bashrc
```

# Usage

```bash
ot              # 60 min, tunneluser
ot root         # 60 min, root (needs SSH key pre-configured)
ot 60           # 60 min, tunneluser  
ot 60 root     # 60 min, root
ot 30 root     # 30 min, root
```

**If using root and SSH key not configured:**
```bash
ot 60 root "ssh-ed25519 AAAA..."
```

---

# How it works

1. **Remote**: Runs `bore local 22 --to bore.pub`
2. **Remote**: Shows `bore.pub:PORT`
3. **Local**: Connect to `bore.pub:PORT`

---

# OpenCode Skill

See `skills/opentunnel-connect/SKILL.md`
