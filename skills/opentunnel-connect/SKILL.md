---
name: opentunnel-connect
description: Connect to remote servers behind NAT using SSH over a Pinggy TCP tunnel (no install, no account, no email).
version: 7.0.0
---

# OpenTunnel Connect Skill

Connect to remote servers behind NAT using SSH over a Pinggy TCP tunnel. Nothing to install on either end (stock `ssh` everywhere), no account, no email anywhere. Plain `ssh -p PORT user@host` on your side.

## Flow

### Step 1: Ask Options

Ask user:
- Username? (default: tunneluser)
- Minutes? (default: 60)

### Step 2: Execute Binary

```powershell
& "$env:USERPROFILE\.config\opencode\skills\opentunnel-connect\opentunnel.exe" --user USERNAME --minutes MINUTES
```

The binary will:
1. Read/create SSH key from `~/.ssh/id_ed25519.pub` (sanitized: type + key only, never sends email/comment)
2. Output the command for the remote server (Linux + Windows versions)
3. Wait for user to paste the `host:port` tunnel address

### Step 3: User Runs Command

Give the command to user to run on **remote server**.

Linux remote:
```bash
curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.sh?v=$(date +%s)" | sudo bash -s -- 60 root "ssh-ed25519 AAAA..."
```

Windows remote (PowerShell as Admin):
```powershell
irm https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.ps1 -OutFile $env:TEMP\ot.ps1; & $env:TEMP\ot.ps1 -Minutes 60 -User Administrator -SshKey "ssh-ed25519 AAAA..."
```

NOTE: the key in the command has NO email/comment. Never append one.

### Step 4: Get Tunnel Info

User must provide: `host:port` (e.g. `abc-12-34-56.run.pinggy-free.link:33045`)

### Step 5: Connect with ezssh

Plain TCP, no ProxyCommand needed:

```javascript
ezssh_ssh_execute({
  command: "hostname && uptime",
  hosts: ["TUNNEL_HOST"],
  port: TUNNEL_PORT,
  username: "USERNAME",
  privateKeyPath: process.env.USERPROFILE + "/.ssh/id_ed25519"
})
```

On Linux/macOS:
```javascript
privateKeyPath: process.env.HOME + "/.ssh/id_ed25519"
```

Or plain ssh:
```bash
ssh -i ~/.ssh/id_ed25519 -p TUNNEL_PORT USERNAME@TUNNEL_HOST
```

## Quick Install (for users)

Linux servers:
```bash
echo 'ot() { curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.sh?v=$(date +%s)" | sudo bash -s -- "${@:-60}"; }' >> ~/.bashrc && source ~/.bashrc
```

Then just run: `ot 60 root`

## Notes

- Free Pinggy tunnels expire after 60 minutes and get a random address each time. That matches the default duration.
- SSH traffic is end-to-end encrypted by sshd itself; the relay only sees ciphertext.
