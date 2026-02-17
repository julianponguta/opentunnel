# OpenTunnel Connect

Connect to remote servers behind NAT/firewall using reverse SSH tunnels.

## Your SSH Key

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFzn4bIIjxL+VO6WCjrvF+rxt3LVi4s4X57ZwP4wnG1h julianponguta@gmail.com
```

---

# Basic Usage (Without Skill)

## Step 1: Start Local Tunnel

Run on your **local machine** (Windows):

```powershell
.\opentunnel.exe --user root --minutes 60
```

Or with custom SSH key:
```powershell
.\opentunnel.exe --user root --minutes 60 --ssh-key "ssh-ed25519 ..."
```

## Step 2: Run Command on Remote Server

The script will output a curl command. Run it on your **remote server**:

```bash
curl -fsSL https://raw.githubusercontent.com/julianponguta/opentunnel/main/skills/opentunnel-connect/scripts/remote.sh | sudo bash -s -- <URL> 60 root --daemon "ssh-ed25519 ..."
```

## Step 3: Get Tunnel Info

The remote server will output:
```
Tunnel: bore.pub:12345
```

## Step 4: Connect

Copy that info and connect:
```bash
ssh -i ~/.ssh/id_ed25519 root@bore.pub -p 12345
```

---

# OpenCode Skill Usage

## For AI Agents

When user wants to connect to a remote server behind NAT:

### Step 1: Ask Options

Ask user:
- Username? (default: tunneluser)
- Minutes? (default: 60)

### Step 2: Execute Binary

```powershell
powershell.exe -Command "& 'C:\Users\Julian\.config\opencode\skills\opentunnel-connect\opentunnel.exe' --user USERNAME --minutes MINUTES"
```

### Step 3: User Runs Command

Give the curl command to user to run on remote server.

### Step 4: Get Tunnel Info

User provides: `bore.pub:PORT`

### Step 5: Connect with ezssh

```javascript
ezssh_ssh_execute({
  command: "hostname && uptime",
  hosts: ["bore.pub"],
  port: PORT,
  username: "USERNAME",
  privateKeyPath: "C:/Users/Julian/.ssh/id_ed25519"
})
```

---

# Files

- `opentunnel.exe` - Standalone binary (Windows, no dependencies)
- `opentunnel.go` - Source code
- `skills/opentunnel-connect/scripts/remote.sh` - Remote server script

---

# Troubleshooting

- **SSH key not working**: Run the curl command on remote - it adds the key automatically
- **Connection refused**: Wait a few seconds for bore to start on remote
- **Tunnel expired**: Run the curl command again on remote
