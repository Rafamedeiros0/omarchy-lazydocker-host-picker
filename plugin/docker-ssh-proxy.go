// Bridge a local Unix socket to Docker's SSH stdio transport.
package main

import (
	"fmt"
	"io"
	"net"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
)

func parseTarget(value string) (string, error) {
	u, err := url.Parse(value)
	if err != nil || u.Scheme != "ssh" || u.Host == "" || u.Path != "" || u.RawQuery != "" || u.Fragment != "" {
		return "", fmt.Errorf("expected an SSH Docker endpoint such as ssh://user@host")
	}
	return u.Host, nil
}

func relay(dst io.Writer, src io.Reader) {
	_, _ = io.Copy(dst, src)
}

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintf(os.Stderr, "Usage: %s ssh://[user@]host\n", os.Args[0])
		os.Exit(2)
	}
	target, err := parseTarget(os.Args[1])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	if _, err := exec.LookPath("ssh"); err != nil {
		fmt.Fprintln(os.Stderr, "Both ssh and lazydocker must be installed")
		os.Exit(127)
	}
	if _, err := exec.LookPath("lazydocker"); err != nil {
		fmt.Fprintln(os.Stderr, "Both ssh and lazydocker must be installed")
		os.Exit(127)
	}

	dir, err := os.MkdirTemp("", "lazydocker-dial-stdio-")
	if err != nil {
		fmt.Fprintln(os.Stderr, "Could not create temporary socket directory:", err)
		os.Exit(1)
	}
	defer os.RemoveAll(dir)
	socketPath := filepath.Join(dir, "docker.sock")
	listener, err := net.Listen("unix", socketPath)
	if err != nil {
		fmt.Fprintln(os.Stderr, "Could not create Docker proxy socket:", err)
		os.Exit(1)
	}
	defer listener.Close()
	if err := os.Chmod(socketPath, 0600); err != nil {
		fmt.Fprintln(os.Stderr, "Could not secure Docker proxy socket:", err)
		os.Exit(1)
	}

	var active sync.Map // map[*exec.Cmd]net.Conn
	var workers sync.WaitGroup
	acceptDone := make(chan struct{})
	go func() {
		defer close(acceptDone)
		for {
			client, err := listener.Accept()
			if err != nil {
				return
			}
			workers.Add(1)
			go func(client net.Conn) {
				defer workers.Done()
				cmd := exec.Command("ssh", target, "docker", "system", "dial-stdio")
				stdin, err := cmd.StdinPipe()
				if err != nil {
					client.Close()
					return
				}
				stdout, err := cmd.StdoutPipe()
				if err != nil {
					client.Close()
					return
				}
				cmd.Stderr = io.Discard
				if err := cmd.Start(); err != nil {
					fmt.Fprintln(os.Stderr, "Could not start SSH Docker transport:", err)
					client.Close()
					return
				}
				active.Store(cmd, client)
				upstreamDone := make(chan struct{})
				go func() {
					_, _ = io.Copy(stdin, client)
					stdin.Close()
					close(upstreamDone)
				}()
				go func() {
					_, _ = io.Copy(client, stdout)
					if unixConn, ok := client.(*net.UnixConn); ok {
						_ = unixConn.CloseWrite()
					}
				}()
				_ = cmd.Wait()
				_ = client.Close()
				<-upstreamDone
				active.Delete(cmd)
			}(client)
		}
	}()

	env := os.Environ()
	for i := range env {
		if strings.HasPrefix(env[i], "DOCKER_HOST=") {
			env[i] = "DOCKER_HOST=unix://" + socketPath
			goto envReady
		}
	}
	env = append(env, "DOCKER_HOST=unix://"+socketPath)
envReady:
	ui := exec.Command("lazydocker")
	ui.Env = env
	ui.Stdin = os.Stdin
	ui.Stdout = os.Stdout
	ui.Stderr = os.Stderr
	err = ui.Run()
	_ = listener.Close()
	<-acceptDone
	active.Range(func(key, value any) bool {
		cmd := key.(*exec.Cmd)
		conn := value.(net.Conn)
		_ = conn.Close()
		if cmd.Process != nil {
			_ = cmd.Process.Kill()
		}
		return true
	})
	workers.Wait()
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			os.Exit(exitErr.ExitCode())
		}
		fmt.Fprintln(os.Stderr, "Could not start lazydocker:", err)
		os.Exit(1)
	}
}
