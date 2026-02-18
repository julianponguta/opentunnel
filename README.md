# OpenTunnel

Connect to remote servers behind NAT using reverse SSH tunnels.

---

# Quick Install

```bash
echo 'ot() { curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.sh?v=$(date +%s)" | sudo bash -s -- "${@}"; }' >> ~/.bashrc && source ~/.bashrc
```

# Usage

```bash
ot 60 root "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFzn4bIIjxL+VO6WCjrvF+rxt3LVi4s4X57ZwP4wnG1h julianponguta@gmail.com"
```

**Arguments:**
1. Minutes (default: 60)
2. Username (default: tunneluser)
3. SSH key (required)

---

# OpenCode Skill

When user wants to connect to a remote server behind NAT:

1. Ask: Username? (default: tunneluser), Minutes? (default: 60)
2. Run `opentunnel.exe --user USERNAME --minutes MINUTES`
3. User runs curl command on remote server
4. User provides `bore.pub:PORT`
5. Connect with ezssh

See `skills/opentunnel-connect/SKILL.md` for full details.

---

# How it works

1. **Remote**: Runs `bore local 22 --to bore.pub` 
2. **Remote**: Shows `bore.pub:PORT`
3. **Local**: Connect to `bore.pub:PORT`
