#!/usr/bin/env bash
# ==============================================================================
# setup_tank.sh
# System Optimization & NVIDIA GPU Passthrough for DevOps & AI Lab
# Target: "Tank" (Ubuntu, AMD Ryzen 5 5600X3D, ASUS X570, NVIDIA RTX 3060)
# ==============================================================================

set -euo pipefail

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root (sudo)." >&2
  exit 1
fi

echo "===================================================================="
echo " Starting System Optimization & Driver Setup for Tank "
echo "===================================================================="

# ------------------------------------------------------------------------------
# 1. Update and Upgrade System Repositories
# ------------------------------------------------------------------------------
echo "Updating apt package list..."
apt-get update -y
apt-get upgrade -y

# ------------------------------------------------------------------------------
# 2. Install NVIDIA Proprietary Drivers
# ------------------------------------------------------------------------------
echo "Installing recommended NVIDIA proprietary drivers..."
# Add official graphics driver PPA for the latest stable releases
add-apt-repository ppa:graphics-drivers/ppa -y
apt-get update -y

# Install the standard recommended driver (550 is current stable LTS)
apt-get install -y nvidia-driver-550-server nvidia-utils-550-server

# ------------------------------------------------------------------------------
# 3. Install Docker (If Not Installed)
# ------------------------------------------------------------------------------
if ! command -v docker &>/dev/null; then
  echo "Docker not found. Installing Docker Engine..."
  apt-get install -y ca-certificates curl gnupg lsb-release
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
  
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi

# ------------------------------------------------------------------------------
# 4. Install NVIDIA Container Toolkit (GPU Passthrough)
# ------------------------------------------------------------------------------
echo "Configuring NVIDIA Container Toolkit repository..."
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg --yes
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

apt-get update -y
apt-get install -y nvidia-container-toolkit

echo "Configuring Docker runtime to use NVIDIA driver..."
nvidia-ctk runtime configure --runtime=docker

echo "Restarting Docker service to apply runtime changes..."
systemctl restart docker

# ------------------------------------------------------------------------------
# 5. Ryzen 5 5600X3D & X570 Kernel Tuning (sysctl)
# ------------------------------------------------------------------------------
echo "Applying kernel and sysctl tuning for Ryzen 5 5600X3D and X570..."

SYSCTL_CONF="/etc/sysctl.d/99-tank-performance.conf"

cat << 'EOF' > "$SYSCTL_CONF"
# ==============================================================================
# Homelab Tuning for Tank (Ryzen 5 5600X3D / ASUS X570)
# Optimized for heavy Docker I/O, compilation throughput, and Ollama LLM latency
# ==============================================================================

# Virtual Memory (VM) Optimizations
# Reduce swappiness to prevent swapping memory segments to disk (important for massive LLM loading)
vm.swappiness = 10
# Avoid kernel locking up during massive disk writes by tuning dirty page writebacks
# Writeback starts when 5% of memory contains dirty pages
vm.dirty_background_ratio = 5
# System forces process to write dirty pages when 15% of memory is dirty
vm.dirty_ratio = 15
# Allow memory overcommit to allocate large contiguous regions for Ollama tensors safely
vm.overcommit_memory = 1

# Filesystem and Descriptor Limits
# Elevate file handle limit to accommodate multiple Docker environments
fs.file-max = 2097152
# Increase filesystem watch limits (Node, Gitea and Docker dev workflows watch thousands of files)
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512

# Network Stack Optimizations
# Increase the backlog queue size for connections (prevents dropped connection requests)
net.core.somaxconn = 2048
net.ipv4.tcp_max_syn_backlog = 4096
# Increase system socket read/write buffer maximum sizes for gigabit/10G network transfers
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
# Enable TCP BBR Congestion Control (requires modern Linux kernel, standard on Ubuntu 22.04+)
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
# Enable forwarding (Docker uses this, but make sure it is system-wide)
net.ipv4.ip_forward = 1
EOF

# Apply sysctl configurations
sysctl --system

# ------------------------------------------------------------------------------
# 6. CPU Power Governor Tuning for Zen 3
# ------------------------------------------------------------------------------
echo "Tuning CPU performance governor..."
if command -v cpupower &>/dev/null; then
  cpupower frequency-set -g performance
elif [ -d /sys/devices/system/cpu/cpu0/cpufreq ]; then
  # Fallback for systems without cpupower tool
  for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
    if [ -f "$cpu/cpufreq/scaling_governor" ]; then
      echo "performance" > "$cpu/cpufreq/scaling_governor"
    fi
  done
else
  echo "CPUpower not installed. Installing cpufrequtils to set performance mode..."
  apt-get install -y cpufrequtils
  echo 'GOVERNOR="performance"' > /etc/default/cpufrequtils
  systemctl restart cpufrequtils || true
fi

# ------------------------------------------------------------------------------
# 7. Create Lab Directories
# ------------------------------------------------------------------------------
echo "Creating lab directories in /opt/homelab..."
mkdir -p /opt/homelab/data/nginx-proxy-manager
mkdir -p /opt/homelab/data/letsencrypt

echo "===================================================================="
echo " Setup complete! Please REBOOT Tank to load NVIDIA drivers and sysctl settings."
echo " Validate configuration post-reboot with: "
echo "   1. nvidia-smi"
echo "   2. docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi"
echo "===================================================================="
