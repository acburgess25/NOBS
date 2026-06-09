// Package installer handles auto-installation of Ollama and Docker
// on Windows, macOS, and Linux — no user interaction required.
package installer

import (
	"fmt"
	"os"
	"os/exec"
	"runtime"
)

// Status tracks what's installed and running.
type Status struct {
	OllamaInstalled bool
	OllamaRunning   bool
	DockerInstalled bool
	DockerRunning   bool
	HARunning       bool
}

// Check returns the current installation status.
func Check() Status {
	return Status{
		OllamaInstalled: commandExists("ollama"),
		OllamaRunning:   serviceRunning("ollama"),
		DockerInstalled: commandExists("docker"),
		DockerRunning:   dockerRunning(),
		HARunning:       containerRunning("homeassistant"),
	}
}

// EnsureAll installs and starts everything needed.
// Progress messages are sent to the out channel.
func EnsureAll(out chan<- string) error {
	out <- "Checking system..."

	if !commandExists("ollama") {
		out <- "Installing Ollama..."
		if err := installOllama(); err != nil {
			return fmt.Errorf("ollama install failed: %w", err)
		}
	}

	out <- "Starting Ollama..."
	if err := startOllama(); err != nil {
		return fmt.Errorf("ollama start failed: %w", err)
	}

	out <- "Pulling AI model (llama3.1:8b)..."
	if err := pullModel("llama3.1:8b"); err != nil {
		// Non-fatal — model download can be slow, retry later
		out <- fmt.Sprintf("Warning: model pull failed (%v), will retry", err)
	}

	if !commandExists("docker") {
		out <- "Installing Docker..."
		if err := installDocker(); err != nil {
			out <- fmt.Sprintf("Docker install failed (%v) — Home Assistant unavailable", err)
		}
	}

	if commandExists("docker") && dockerRunning() {
		if !containerRunning("homeassistant") {
			out <- "Starting Home Assistant..."
			if err := startHomeAssistant(); err != nil {
				out <- fmt.Sprintf("Home Assistant failed (%v)", err)
			}
		}
	}

	out <- "Ready"
	return nil
}

// ─── Ollama ────────────────────────────────────────────────────────────────

func installOllama() error {
	switch runtime.GOOS {
	case "darwin":
		// macOS: brew install
		if commandExists("brew") {
			return run("brew", "install", "ollama")
		}
		// Fallback: curl installer
		return run("sh", "-c", "curl -fsSL https://ollama.com/install.sh | sh")
	case "linux":
		return run("sh", "-c", "curl -fsSL https://ollama.com/install.sh | sh")
	case "windows":
		// Download and run the Windows installer silently
		tmpPath := os.TempDir() + "\\ollama-installer.exe"
		if err := downloadFile("https://ollama.com/download/OllamaSetup.exe", tmpPath); err != nil {
			return err
		}
		return run(tmpPath, "/S") // silent install
	default:
		return fmt.Errorf("unsupported OS: %s", runtime.GOOS)
	}
}

func startOllama() error {
	switch runtime.GOOS {
	case "darwin":
		// Start as background service
		_ = run("brew", "services", "start", "ollama")
		return nil
	case "linux":
		_ = run("systemctl", "--user", "start", "ollama")
		return nil
	case "windows":
		cmd := exec.Command("ollama", "serve")
		cmd.Stdout = nil
		cmd.Stderr = nil
		return cmd.Start()
	}
	return nil
}

func pullModel(model string) error {
	return run("ollama", "pull", model)
}

// ─── Docker & Home Assistant ───────────────────────────────────────────────

func installDocker() error {
	switch runtime.GOOS {
	case "darwin":
		if commandExists("brew") {
			return run("brew", "install", "--cask", "docker")
		}
		return fmt.Errorf("install Docker Desktop manually from docker.com")
	case "linux":
		return run("sh", "-c", "curl -fsSL https://get.docker.com | sh")
	case "windows":
		tmpPath := os.TempDir() + "\\DockerInstaller.exe"
		if err := downloadFile("https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe", tmpPath); err != nil {
			return err
		}
		return run(tmpPath, "install", "--quiet")
	}
	return nil
}

func startHomeAssistant() error {
	return run("docker", "run", "-d",
		"--name", "homeassistant",
		"--restart", "unless-stopped",
		"--network", "host",
		"--privileged",
		"-v", nobsDataDir()+"/homeassistant:/config",
		"-e", "TZ=America/Chicago",
		"ghcr.io/home-assistant/home-assistant:stable",
	)
}

// ─── Helpers ───────────────────────────────────────────────────────────────

func commandExists(cmd string) bool {
	_, err := exec.LookPath(cmd)
	return err == nil
}

func serviceRunning(name string) bool {
	err := exec.Command("pgrep", "-x", name).Run()
	return err == nil
}

func dockerRunning() bool {
	err := exec.Command("docker", "info").Run()
	return err == nil
}

func containerRunning(name string) bool {
	out, err := exec.Command("docker", "ps", "--filter", "name="+name, "--format", "{{.Names}}").Output()
	return err == nil && len(out) > 0
}

func run(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func nobsDataDir() string {
	home, _ := os.UserHomeDir()
	dir := home + "/.nobs-server"
	_ = os.MkdirAll(dir, 0755)
	return dir
}

func downloadFile(url, dest string) error {
	return run("curl", "-fsSL", "-o", dest, url)
}
