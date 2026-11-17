//go:build !windows

package main

import (
	"os/exec"
	"syscall"
)

func detachProc(c *exec.Cmd) {
	c.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
}
