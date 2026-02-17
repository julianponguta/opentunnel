# OpenTunnel Fix Implementation Plan

> **For Claude:** Use superpowers:executing-plans to implement this plan.

**Goal:** Fix the OpenTunnel binary and remote script so SSH key authentication works properly.

**Architecture:** 
- Fix Go code to properly read/generate SSH keys
- Fix remote.sh to add SSH key even when user already exists

**Tech Stack:** Go (opentunnel.go), Bash (remote.sh)

---

## Task 1: Fix Go SSH Key Reading

**Files:**
- Modify: `C:\Users\Julian\Documents\opentunnel\opentunnel.go`

**Step 1: Fix the SSH key reading to handle files without newlines**

```go
func getSSHKey() string {
	homeDir := os.Getenv("USERPROFILE")
	if homeDir == "" {
		homeDir = os.Getenv("HOME")
	}
	
	sshDir := filepath.Join(homeDir, ".ssh")
	keyPath := filepath.Join(sshDir, "id_ed25519.pub")
	privateKeyPath := filepath.Join(sshDir, "id_ed25519")
	
	if _, err := os.Stat(privateKeyPath); os.IsNotExist(err) {
		fmt.Println("[*] SSH key not found, generating one...")
		
		os.MkdirAll(sshDir, 0700)
		
		cmd := exec.Command("ssh-keygen", "-t", "ed25519", "-f", privateKeyPath, "-N", "", "-C", "opentunnel")
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stdout
		cmd.Run()
		
		fmt.Println("[+] SSH key generated!")
	}
	
	data, err := os.ReadFile(keyPath)
	if err == nil {
		// Trim whitespace and newlines properly
		key := strings.TrimSpace(string(data))
		return key
	}
	
	return ""
}
```

**Step 2: Add "strings" import if not present**

Check imports at top of file include "strings"

**Step 3: Compile and test**

```bash
cd C:/Users/Julian/Documents/opentunnel && go build -o opentunnel.exe opentunnel.go
```

---

## Task 2: Fix remote.sh SSH Key Addition

**Files:**
- Modify: `C:\Users\Julian\Documents\opentunnel\skills\opentunnel-connect\scripts\remote.sh`

**Step 1: Verify setup_user function adds key for existing users**

The function at line 101-124 should check for SSH_KEY even when user exists:

```bash
setup_user() {
    if [ -n "$SSH_KEY" ]; then
        setup_user_with_key "$TEMP_USER" "$SSH_KEY"
        echo "key-based"
        return 0
    fi
    
    if id "${TEMP_USER}" &>/dev/null; then
        log_info "User ${TEMP_USER} already exists"
        if [ -n "$SSH_KEY" ]; then
            setup_user_with_key "$TEMP_USER" "$SSH_KEY"
            echo "key-based"
        else
            echo "existing"
        fi
        return 0
    fi
    
    # ... rest of function
}
```

**Step 2: Test by running remote.sh manually on test server**

---

## Task 3: Copy Updated Files

**Files:**
- Copy: `opentunnel.exe` to skill directory

```bash
cp C:/Users/Julian/Documents/opentunnel/opentunnel.exe C:/Users/Julian/.config/opencode/skills/opentunnel-connect/
```

---

## Task 4: Test Full Flow

**Step 1: Run opentunnel.exe locally**

```powershell
.\opentunnel.exe --user root --minutes 60
```

**Step 2: Run curl command on remote server**

**Step 3: Verify Auth shows "key" not "password"**

**Step 4: Test SSH connection with ezssh

---

## Task 5: Commit Changes

```bash
git add opentunnel.go opentunnel.exe skills/opentunnel-connect/scripts/remote.sh
git commit -m "Fix SSH key handling - proper read and existing user key addition"
git push
```
