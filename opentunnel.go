package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
)

// sanitizeKey devuelve solo "tipo base64", sin comentario/email.
// Ej: "ssh-ed25519 AAAA... julian@gmail.com" -> "ssh-ed25519 AAAA..."
func sanitizeKey(key string) string {
	fields := strings.Fields(strings.TrimSpace(key))
	if len(fields) >= 2 {
		return fields[0] + " " + fields[1]
	}
	return strings.TrimSpace(key)
}

func getSSHKey() string {
	homeDir := os.Getenv("USERPROFILE")
	if homeDir == "" {
		homeDir = os.Getenv("HOME")
	}

	sshDir := filepath.Join(homeDir, ".ssh")
	keyPath := filepath.Join(sshDir, "id_ed25519.pub")
	privateKeyPath := filepath.Join(sshDir, "id_ed25519")

	if _, err := os.Stat(privateKeyPath); os.IsNotExist(err) {
		fmt.Println("[*] SSH key not found, generating one (sin email, comentario 'opentunnel')...")

		os.MkdirAll(sshDir, 0700)

		// -C opentunnel: evita que tu email quede en la llave
		cmd := exec.Command("ssh-keygen", "-t", "ed25519", "-f", privateKeyPath, "-N", "", "-C", "opentunnel")
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stdout
		cmd.Run()

		fmt.Println("[+] SSH key generated!")
	}

	data, err := os.ReadFile(keyPath)
	if err == nil {
		return sanitizeKey(string(data))
	}

	return ""
}

func main() {
	user := "tunneluser"
	minutes := 60
	noKey := false
	sshKey := getSSHKey()

	if sshKey == "" {
		fmt.Println("[-] Error: Could not generate or find SSH key")
		os.Exit(1)
	}

	args := os.Args[1:]
	for i := 0; i < len(args); i++ {
		if args[i] == "--user" && i+1 < len(args) {
			user = args[i+1]
			i++
		} else if args[i] == "--minutes" && i+1 < len(args) {
			fmt.Sscanf(args[i+1], "%d", &minutes)
			i++
		} else if args[i] == "--ssh-key" && i+1 < len(args) {
			sshKey = sanitizeKey(args[i+1])
			i++
		} else if args[i] == "--no-key" {
			noKey = true
		}
	}

	keyArg := ""
	if !noKey {
		keyArg = fmt.Sprintf(` "%s"`, sshKey)
	}

	fmt.Println("========================================")
	fmt.Println("OpenTunnel Connect (Pinggy TCP)")
	fmt.Println("========================================")

	if noKey {
		fmt.Println("\n[OK] Modo sin llave: el remoto creara password temporal.")
		fmt.Println("    No se envia NADA de tu llave en el comando.")
	} else {
		fmt.Println("\n[OK] Tu llave lista (sanitizada, sin email):")
		fmt.Printf("    %s\n", sshKey)
	}

	fmt.Println("\n========================================")
	fmt.Println("RUN THIS COMMAND ON REMOTE SERVER:")
	fmt.Println("========================================")

	fmt.Println("\n-- Linux remoto: --")
	fmt.Printf("curl -fsSL \"https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.sh?v=$(date +%%s)\" | sudo bash -s -- %d %s%s\n", minutes, user, keyArg)

	fmt.Println("\n-- Windows remoto (PowerShell como Admin): --")
	psKey := ""
	if !noKey {
		psKey = fmt.Sprintf(` -SshKey "%s"`, sshKey)
	}
	fmt.Printf("irm https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.ps1 -OutFile $env:TEMP\\ot.ps1; & $env:TEMP\\ot.ps1 -Minutes %d -User %s%s\n", minutes, user, psKey)

	fmt.Println("========================================")
	fmt.Println("\n[OK] Sin instalar nada en ningun lado: solo ssh (ya viene en el sistema).")
	fmt.Println("    Sin cuentas, sin emails. El trafico SSH va cifrado de extremo a extremo.")
	fmt.Println("\n[INPUT] Pega el tunel que te dio el remoto (ej: abc-12-34-56.run.pinggy-free.link:33045):")

	reader := bufio.NewReader(os.Stdin)
	rawInput, _ := reader.ReadString('\n')
	rawInput = strings.TrimSpace(rawInput)
	// Acepta con o sin prefijo tcp://
	rawInput = strings.TrimPrefix(rawInput, "tcp://")

	// host:puerto (el host puede ser .pinggy.link, .pinggy-free.link, etc.)
	re := regexp.MustCompile(`^([A-Za-z0-9.-]+):([0-9]+)$`)
	m := re.FindStringSubmatch(rawInput)
	if m == nil {
		fmt.Println("[-] Formato invalido. Esperado: host:puerto")
		os.Exit(1)
	}
	host, port := m[1], m[2]

	fmt.Println("\n--- CREDENTIALS ---")
	fmt.Printf("HOST_PORT=%s:%s\n", host, port)
	fmt.Printf("USER=%s\n", user)
	fmt.Println("--- END CREDENTIALS ---")

	fmt.Println("\n[OK] Conectate asi (ssh pelado):")
	if noKey {
		fmt.Printf("    ssh -p %s %s@%s\n", port, user, host)
	} else {
		fmt.Printf("    ssh -i ~/.ssh/id_ed25519 -p %s %s@%s\n", port, user, host)
	}
}
