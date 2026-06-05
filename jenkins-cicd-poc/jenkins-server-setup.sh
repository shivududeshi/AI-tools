#!/bin/bash
# ============================================================
# jenkins-server-setup.sh
# Run this script on the JENKINS SERVER EC2 instance (Ubuntu 24.04)
#
# What this script does:
#   - Installs Docker
#   - Creates /var/jenkins_home as persistent Jenkins data volume
#   - Runs Jenkins in a Docker container (jenkins/jenkins:lts-jdk17)
#   - Prints the initial admin password
#
# Usage:
#   chmod +x jenkins-server-setup.sh
#   sudo ./jenkins-server-setup.sh
# ============================================================

set -euo pipefail

echo "============================================="
echo " Jenkins Server Setup — Ubuntu 24.04 LTS"
echo "============================================="

# ── 1. System update ──────────────────────────────────────────
echo "[1/5] Updating system packages..."
apt-get update -y
apt-get upgrade -y
apt-get install -y curl wget gnupg2 ca-certificates lsb-release \
                   apt-transport-https software-properties-common unzip git

# ── 2. Install Docker ─────────────────────────────────────────
echo "[2/5] Installing Docker..."

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

# Allow ubuntu user to run Docker without sudo
usermod -aG docker ubuntu

# ── 3. Create Jenkins data directory ─────────────────────────
# This directory is mounted into the Jenkins container so that
# all Jenkins config, jobs, and plugins survive container restarts.
echo "[3/5] Creating Jenkins home directory at /var/jenkins_home..."
mkdir -p /var/jenkins_home
# Container runs as root (--user root) so no chown needed
chmod 755 /var/jenkins_home

# ── 4. Start Jenkins container ───────────────────────────────
echo "[4/5] Starting Jenkins container..."

# Stop and remove any existing Jenkins container first
docker stop jenkins-server 2>/dev/null || true
docker rm   jenkins-server 2>/dev/null || true

# Notes on flags used:
#   --user root              : lets Jenkins write to the mounted volume freely
#   -p 8080:8080             : Jenkins web UI
#   -p 50000:50000           : not used by SSH launch but kept for completeness
#   -v /var/jenkins_home     : persistent data volume
#   -v /var/run/docker.sock  : allows Jenkins to run Docker commands on the host
#   --restart=unless-stopped : auto-restart on EC2 reboot

docker run -d \
    --name jenkins-server \
    --restart=unless-stopped \
    --user root \
    -p 8080:8080 \
    -p 50000:50000 \
    -v /var/jenkins_home:/var/jenkins_home \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -e JENKINS_HOME=/var/jenkins_home \
    jenkins/jenkins:lts-jdk17

echo "Jenkins container started. Waiting ~60s for initialization..."
sleep 60

# ── 5. Print initial admin password ──────────────────────────
echo "[5/5] Retrieving initial admin password..."
echo ""
echo "============================================="
echo " Jenkins Initial Admin Password:"
echo "============================================="

docker exec jenkins-server \
    cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null \
    || cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null \
    || echo "Not ready yet. Retry with:"
       echo "  docker exec jenkins-server cat /var/jenkins_home/secrets/initialAdminPassword"

echo ""
PUBLIC_IP=$(curl -s --max-time 3 http://169.254.169.254/latest/meta-data/public-ipv4 || echo "<SERVER_PUBLIC_IP>")
echo "============================================="
echo " Jenkins is running at: http://${PUBLIC_IP}:8080"
echo "============================================="
echo ""
echo "Next steps:"
echo "  1. Open http://${PUBLIC_IP}:8080 in your browser"
echo "  2. Paste the admin password printed above"
echo "  3. Choose 'Install suggested plugins' and wait"
echo "  4. Install extra plugins: Docker Pipeline, SSH Build Agents, GitHub"
echo "  5. Create your admin user"
echo "  6. Run jenkins-agent-setup.sh on the agent EC2"
echo "  7. Configure the agent node in Jenkins UI (see SETUP_GUIDE.md § 6)"
