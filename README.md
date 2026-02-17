# OpenTunnel

One-command SSH tunnel to access remote servers instantly.

## Quick Start (Recommended)

### 1. Setup (once)

```bash
echo 'ot() { curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.sh?v=$(date +%s)" | sudo bash -s -- "${@:-60}"; }' >> ~/.bashrc && source ~/.bashrc
```

### 2. Use

```bash
ot                  # 60 minutes, tunneluser (default)
ot 30              # 30 minutes, tunneluser
ot root            # 60 minutes, root
ot ubuntu          # 60 minutes, ubuntu
ot 30 root         # 30 minutes, root
ot root 30         # 30 minutes, root (any order)
```

## Direct Install (No Setup)

For one-time use, run directly:

```bash
curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.sh?v=$(date +%s)" | sudo bash -s -- 30
```

With custom user:

```bash
curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.sh?v=$(date +%s)" | sudo bash -s -- root
curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.sh?v=$(date +%s)" | sudo bash -s -- 30 root
```

## What It Does

1. Installs `bore` (if not present)
2. Creates temporary user with password
3. Starts tunnel to bore.pub
4. Sets auto-cleanup timer

## Output

You'll get:

```
========================================================
              OPENTUNNEL READY
========================================================

User:     tunneluser
Password: otp_abc123

Connect with:
------------------------------------------------------------
ssh -p 12345 tunneluser@bore.pub
------------------------------------------------------------

Expires in: 30 minutes
========================================================
```

## Connect from Windows

```powershell
ssh -p 12345 tunneluser@bore.pub
# Then enter the password when prompted
```

## Connect from Linux/Mac

```bash
ssh -p 12345 tunneluser@bore.pub
# Then enter the password when prompted
```

## Requirements

- Linux server with SSH running
- sudo/root access
- Internet connection

## Security

- Auto-expires after configured minutes
- User is deleted automatically
- No persistent access left behind
- Password is unique each session
