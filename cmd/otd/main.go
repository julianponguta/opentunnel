// otd — OpenTunnel remote agent.
//
// Line A: exposes a local TCP port (22 by default) through the Portal relay
// network (github.com/gosuda/portal-tunnel). No account, no card, no expiry.
// Every relay endpoint the agent announces is validated end-to-end (TCP dial +
// SSH banner) before being printed, so the caller never gets a dead address.
package main

import (
	"bufio"
	"flag"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"os/user"
	"path/filepath"
	"regexp"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
)

const portalVersion = "v2.7.4"

var (
	// tcp_addr=ot-a1b2-f012d64d....s-h.day:50003
	tcpAddrRE = regexp.MustCompile(`tcp_addr=([A-Za-z0-9][A-Za-z0-9._-]*:[0-9]{1,5})`)
	// portal colorizes its log on Linux (`ESC[36mtcp_addr=ESC[0m...`), which breaks
	// the literal match; Windows output is plain.
	ansiRE = regexp.MustCompile("\\x1b\\[[0-9;]*m")
)

func logf(format string, a ...any) {
	fmt.Fprintf(os.Stderr, "[otd] "+format+"\n", a...)
}

func main() {
	port := flag.Int("port", 22, "local TCP port to expose")
	portalBin := flag.String("portal", "", "path to an existing portal binary (skips download)")
	timeout := flag.Duration("timeout", 90*time.Second, "give up if no validated endpoint within this window")
	noCheck := flag.Bool("no-health-check", false, "print the first announced endpoint without validating it")
	verbose := flag.Bool("v", false, "stream relay output")
	shellMode := flag.Bool("shell", false, "serve SSH from this process (no system sshd needed)")
	authKey := flag.String("authorized-key", "", "public key allowed into the embedded server")
	authKeyFile := flag.String("authorized-key-file", "", "file with authorized_keys for the embedded server")
	flag.Parse()

	localPort, user := *port, currentUser()
	if *shellMode {
		keys, err := loadKeys(*authKey, *authKeyFile)
		if err != nil {
			fmt.Fprintf(os.Stderr, "[-] %v\n", err)
			os.Exit(1)
		}
		addr, err := startEmbeddedSSH(keys)
		if err != nil {
			fmt.Fprintf(os.Stderr, "[-] ssh embebido: %v\n", err)
			os.Exit(1)
		}
		_, p, _ := net.SplitHostPort(addr)
		localPort, _ = strconv.Atoi(p)
		logf("ssh embebido en %s (sin sshd del sistema, solo con llave)", addr)
	}

	if err := run(localPort, user, *portalBin, *timeout, *noCheck, *verbose); err != nil {
		fmt.Fprintf(os.Stderr, "[-] %v\n", err)
		os.Exit(1)
	}
}

func run(port int, user, portalBin string, timeout time.Duration, noCheck, verbose bool) error {
	bin, workDir, err := ensurePortal(portalBin)
	if err != nil {
		return err
	}
	logf("portal %s, exponiendo 127.0.0.1:%d", portalVersion, port)

	cmd := exec.Command(bin, "expose", fmt.Sprintf("127.0.0.1:%d", port), "--tcp")
	// portal writes identity.json (its device key, which also seeds the stable
	// public hostname) into the working directory. Keep it in the cache, never
	// in whatever directory the operator happened to be in.
	cmd.Dir = workDir
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return err
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return err
	}
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("no se pudo ejecutar %s: %w", bin, err)
	}

	sig := make(chan os.Signal, 1)
	signal.Notify(sig, os.Interrupt, syscall.SIGTERM)

	published := make(chan struct{})
	var once sync.Once
	var scan sync.WaitGroup
	publish := func(addr string) {
		report(addr, user)
		close(published)
	}
	scan.Add(2)
	go scanAddrs(stdout, noCheck, verbose, &once, publish, &scan)
	go scanAddrs(stderr, noCheck, verbose, &once, publish, &scan)

	done := make(chan error, 1)
	go func() {
		scan.Wait()
		done <- cmd.Wait()
	}()

	// Keep the relay alive after publishing; a nil channel blocks forever.
	deadline := time.After(timeout)
	ok := false
	for {
		select {
		case <-sig:
			_ = cmd.Process.Kill()
			return nil
		case err := <-done:
			if ok {
				return fmt.Errorf("el relay terminó (%v); el endpoint quedó muerto", err)
			}
			return fmt.Errorf("el relay terminó sin endpoint válido (%v)", err)
		case <-published:
			ok = true
			published, deadline = nil, nil
		case <-deadline:
			_ = cmd.Process.Kill()
			return fmt.Errorf("sin endpoint validado tras %s", timeout)
		}
	}
}

func currentUser() string {
	// os/user is the account name; the environment is unreliable: on Windows
	// USER can hold the machine account ("DESKTOP-XXXX$"), not the login.
	if u, err := user.Current(); err == nil && u.Username != "" {
		name := u.Username
		if i := strings.LastIndexAny(name, `\`); i >= 0 {
			name = name[i+1:]
		}
		return name
	}
	if runtime.GOOS == "windows" {
		if u := os.Getenv("USERNAME"); u != "" {
			return u
		}
	}
	if u := os.Getenv("USER"); u != "" {
		return u
	}
	return "user"
}

func scanAddrs(r io.Reader, noCheck, verbose bool, once *sync.Once, printed func(string), wg *sync.WaitGroup) {
	defer wg.Done()
	sc := bufio.NewScanner(r)
	sc.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	for sc.Scan() {
		line := ansiRE.ReplaceAllString(sc.Text(), "")
		if verbose {
			logf("%s", line)
		}
		m := tcpAddrRE.FindStringSubmatch(line)
		if m == nil {
			continue
		}
		addr := m[1]
		if !noCheck {
			if err := sshReady(addr, 6*time.Second); err != nil {
				logf("descartado %s: %v", addr, err)
				continue
			}
		}
		once.Do(func() { printed(addr) })
	}
}

func report(addr, user string) {
	host, p, _ := net.SplitHostPort(addr)
	fmt.Println("========================================================")
	fmt.Println("              CONNECTED")
	fmt.Println("========================================================")
	fmt.Println()
	fmt.Printf("Tunnel: %s\n", addr)
	fmt.Println()
	fmt.Println("CONNECT FROM LOCAL (plain ssh, nada que instalar):")
	fmt.Printf("  ssh -p %s %s@%s\n", p, user, host)
	fmt.Println()
	fmt.Println("Paste in opentunnel: " + addr)
	fmt.Println("========================================================")
}

// sshReady proves relay -> backend -> local sshd works, not just that the relay
// handed out a port. A relay that answers but never forwards fails here.
func sshReady(addr string, d time.Duration) error {
	conn, err := net.DialTimeout("tcp", addr, d)
	if err != nil {
		return err
	}
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(d))
	buf := make([]byte, 32)
	n, err := conn.Read(buf)
	if err != nil {
		return err
	}
	if !strings.HasPrefix(string(buf[:n]), "SSH-") {
		return fmt.Errorf("no es un sshd: %q", strings.TrimSpace(string(buf[:n])))
	}
	return nil
}

func ensurePortal(override string) (bin, workDir string, err error) {
	dir, err := os.UserCacheDir()
	if err != nil {
		dir = os.TempDir()
	}
	dir = filepath.Join(dir, "opentunnel")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", "", err
	}
	if override != "" {
		return override, dir, nil
	}
	ext := ""
	if runtime.GOOS == "windows" {
		ext = ".exe"
	}
	dst := filepath.Join(dir, fmt.Sprintf("portal-%s-%s-%s%s", portalVersion, runtime.GOOS, runtime.GOARCH, ext))
	if st, err := os.Stat(dst); err == nil && st.Size() > 1<<20 {
		return dst, dir, nil
	}
	url := fmt.Sprintf("https://github.com/gosuda/portal-tunnel/releases/download/%s/portal-%s-%s%s",
		portalVersion, runtime.GOOS, runtime.GOARCH, ext)
	logf("descargando %s", url)

	resp, err := http.Get(url)
	if err != nil {
		return "", "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return "", "", fmt.Errorf("descarga falló: HTTP %d", resp.StatusCode)
	}
	tmp := dst + ".part"
	f, err := os.Create(tmp)
	if err != nil {
		return "", "", err
	}
	if _, err := io.Copy(f, resp.Body); err != nil {
		f.Close()
		os.Remove(tmp)
		return "", "", err
	}
	if err := f.Close(); err != nil {
		return "", "", err
	}
	if err := os.Chmod(tmp, 0o755); err != nil && runtime.GOOS != "windows" {
		return "", "", err
	}
	if err := os.Rename(tmp, dst); err != nil {
		return "", "", err
	}
	return dst, dir, nil
}
