#!/bin/bash
# ============================================================
# jenkins-agent-setup.sh
# Run this script on the JENKINS AGENT EC2 instance (Ubuntu 24.04)
#
# Launch method used: Launch agents via SSH
#
# How SSH launch works:
#   - Jenkins SERVER SSHes into this agent machine
#   - Jenkins copies remoting.jar over SFTP
#   - Jenkins runs: java -jar remoting.jar  (on this machine)
#   - Jenkins manages the connection — nothing runs here manually
#
# What this script does:
#   - Installs Java 17   (so Jenkins can run remoting.jar)
#   - Installs Docker    (so the pipeline can run docker build/run)
#   - Adds ubuntu user to docker group
#
# What this script does NOT do (not needed for SSH launch):
#   - No token or secret setup
#   - No systemd service for the agent
#   - No jenkins user creation
#   - No agent.jar download
#
# Usage:
#   chmod +x jenkins-agent-setup.sh
#   sudo ./jenkins-agent-setup.sh
# ============================================================

set -euo pipefail

echo "============================================="
echo " Jenkins Agent Setup — Ubuntu 24.04 LTS"
echo " Launch method: SSH (initiated by Jenkins server)"
echo "============================================="

# ── 1. System update ──────────────────────────────────────────
echo "[1/4] Updating system packages..."
apt-get update -y
apt-get upgrade -y
apt-get install -y curl wget ca-certificates lsb-release \
                   apt-transport-https software-properties-common git unzip

# ── 2. Install Java 17 ────────────────────────────────────────
# Jenkins copies remoting.jar to this machine via SFTP and runs it with java.
# Java must be installed and on PATH before the agent can connect.
echo "[2/4] Installing Java 17..."
apt-get install -y openjdk-17-jdk-headless

echo "Java installed at: $(which java)"
java -version

# ── 3. Install Docker ─────────────────────────────────────────
# The pipeline runs docker build and docker run on this agent.
# Docker must be installed before any pipeline job runs.
echo "[3/4] Installing Docker..."

# Remove any old/conflicting packages
apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker apt repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io \
                   docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl start docker

echo "Docker installed: $(docker --version)"

# ── 4. Grant ubuntu user Docker access ───────────────────────
# Jenkins SSHes in as 'ubuntu'. That user needs to run docker
# commands without sudo during pipeline builds.
echo "[4/4] Adding ubuntu to docker group..."
usermod -aG docker ubuntu

# ── Summary ───────────────────────────────────────────────────
echo ""
echo "============================================="
echo " Agent machine is ready!"
echo "============================================="
echo ""
echo "  Java  : $(java -version 2>&1 | head -1)"
echo "  Docker: $(docker --version)"
echo "  This machine's private IP: $(hostname -I | awk '{print $1}')"
echo ""
echo "NO further action needed on this machine."
echo ""
echo "Go to Jenkins UI and do the following:"
echo "  1. Manage Jenkins → Credentials → Add Credential"
echo "     Kind     : SSH Username with private key"
echo "     Username : ubuntu"
echo "     Key      : paste your .pem file contents"
echo ""
echo "  2. Manage Jenkins → Nodes → petclinic-agent → Configure"
echo "     Launch method  : Launch agents via SSH"
echo "     Host           : $(hostname -I | awk '{print $1}')"
echo "     Credentials    : the credential created above"
echo "     Remote root    : /home/ubuntu/agent"
echo "     Java Path      : /usr/bin/java  (under Advanced)"
echo ""
echo "  3. Save → click 'Launch agent'"
echo "     Jenkins will SSH in, copy remoting.jar, and start the agent."
echo "     You should see: Agent successfully connected and online"
echo ""
echo "IMPORTANT: Log out and back in once for docker group to take effect."
echo "  (The pipeline does not need this — it applies to your SSH session only)"
