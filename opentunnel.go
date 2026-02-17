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
	fmt.Println("OpenTunnel Connect")
	fmt.Println("========================================")

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
	fmt.Println("\nWaiting for connection...")
	time.Sleep(2 * time.Second)

	listener, err := net.Listen("tcp", ":2222")
	if err != nil {
		fmt.Printf("[-] Failed to listen: %v\n", err)
		tunnelCmd.Process.Kill()
		os.Exit(1)
	}
	defer listener.Close()

	conn, err := listener.Accept()
	if err != nil {
		fmt.Printf("[-] Failed to accept: %v\n", err)
		tunnelCmd.Process.Kill()
		os.Exit(1)
	}
	defer conn.Close()

	fmt.Println("[+] Connected!")

	sshConn, err := net.Dial("tcp", "localhost:22")
	if err != nil {
		fmt.Printf("[-] Failed to connect to local SSH: %v\n", err)
		os.Exit(1)
	}
	defer sshConn.Close()

	done := make(chan bool, 2)

	go func() { io.Copy(conn, sshConn); done <- true }()
	go func() { io.Copy(sshConn, conn); done <- true }()

	<-done
	fmt.Println("\n[!] Connection closed.")
}
