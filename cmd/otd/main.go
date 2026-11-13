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
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
	"sync"
	"time"
)

const portalVersion = "v2.7.4"

var (
	// tcp_addr=ot-a1b2-f012d64d....s-h.day:50003
	tcpAddrRE = regexp.MustCompile(`tcp_addr=([A-Za-z0-9][A-Za-z0-9._-]*:[0-9]{1,5})`)
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
	flag.Parse()

	if err := run(*port, *portalBin, *timeout, *noCheck, *verbose); err != nil {
		fmt.Fprintf(os.Stderr, "[-] %v\n", err)
		os.Exit(1)
	}
}

func run(port int, portalBin string, timeout time.Duration, noCheck, verbose bool) error {
	bin, err := ensurePortal(portalBin)
	if err != nil {
		return err
	}
	logf("portal %s, exponiendo 127.0.0.1:%d", portalVersion, port)

	cmd := exec.Command(bin, "expose", fmt.Sprintf("127.0.0.1:%d", port), "--tcp")
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
	signal.Notify(sig, os.Interrupt)

	printed := make(chan struct{})
	var once sync.Once
	var scan sync.WaitGroup
	scan.Add(2)
	go scanAddrs(stdout, noCheck, verbose, &once, printed, &scan)
	go scanAddrs(stderr, noCheck, verbose, &once, printed, &scan)

	done := make(chan error, 1)
	go func() {
		scan.Wait()
		done <- cmd.Wait()
	}()

	// Keep the relay alive after publishing; a nil channel blocks forever.
	deadline := time.After(timeout)
	published := false
	for {
		select {
		case <-sig:
			_ = cmd.Process.Kill()
			return nil
		case err := <-done:
			if published {
				return fmt.Errorf("el relay terminó (%v); el endpoint quedó muerto", err)
			}
			return fmt.Errorf("el relay terminó sin endpoint válido (%v)", err)
		case <-printed:
			published = true
			printed, deadline = nil, nil
		case <-deadline:
			_ = cmd.Process.Kill()
			return fmt.Errorf("sin endpoint validado tras %s", timeout)
		}
	}
}

func scanAddrs(r io.Reader, noCheck, verbose bool, once *sync.Once, printed chan struct{}, wg *sync.WaitGroup) {
	defer wg.Done()
	sc := bufio.NewScanner(r)
	sc.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	for sc.Scan() {
		line := sc.Text()
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
		once.Do(func() {
			report(addr)
			close(printed)
		})
	}
}

func report(addr string) {
	host, p, _ := net.SplitHostPort(addr)
	fmt.Println("========================================================")
	fmt.Println("              CONNECTED")
	fmt.Println("========================================================")
	fmt.Println()
	fmt.Printf("Tunnel: %s\n", addr)
	fmt.Println()
	fmt.Println("CONNECT FROM LOCAL (plain ssh, nada que instalar):")
	fmt.Printf("  ssh -p %s <user>@%s\n", p, host)
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

func ensurePortal(override string) (string, error) {
	if override != "" {
		return override, nil
	}
	dir, err := os.UserCacheDir()
	if err != nil {
		dir = os.TempDir()
	}
	dir = filepath.Join(dir, "opentunnel")
	ext := ""
	if runtime.GOOS == "windows" {
		ext = ".exe"
	}
	dst := filepath.Join(dir, fmt.Sprintf("portal-%s-%s-%s%s", portalVersion, runtime.GOOS, runtime.GOARCH, ext))
	if st, err := os.Stat(dst); err == nil && st.Size() > 1<<20 {
		return dst, nil
	}
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", err
	}
	url := fmt.Sprintf("https://github.com/gosuda/portal-tunnel/releases/download/%s/portal-%s-%s%s",
		portalVersion, runtime.GOOS, runtime.GOARCH, ext)
	logf("descargando %s", url)

	resp, err := http.Get(url)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("descarga falló: HTTP %d", resp.StatusCode)
	}
	tmp := dst + ".part"
	f, err := os.Create(tmp)
	if err != nil {
		return "", err
	}
	if _, err := io.Copy(f, resp.Body); err != nil {
		f.Close()
		os.Remove(tmp)
		return "", err
	}
	if err := f.Close(); err != nil {
		return "", err
	}
	if err := os.Chmod(tmp, 0o755); err != nil && runtime.GOOS != "windows" {
		return "", err
	}
	if err := os.Rename(tmp, dst); err != nil {
		return "", err
	}
	return dst, nil
}
