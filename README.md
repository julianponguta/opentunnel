# OpenTunnel

One-command SSH tunnel to access remote servers instantly.

## Quick Start

### 1. Setup (once)

```bash
echo 'ot() { curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.sh?v=$(date +%s)" | sudo bash -s -- "${@:-60}"; }' >> ~/.bashrc && source ~/.bashrc
```

### 2. Use

```bash
ot 30              # 30 minutes, user: tunneluser
ot 60              # 60 minutes (default), user: tunneluser
ot 30 root         # 30 minutes, user: root
ot 30 ubuntu       # 30 minutes, user: ubuntu
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
