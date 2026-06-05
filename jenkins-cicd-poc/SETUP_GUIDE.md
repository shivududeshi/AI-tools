# Jenkins CI/CD POC — Setup Guide

> Spring PetClinic · AWS EC2 · Ubuntu 24.04 · Docker · Jenkins LTS

---

## How Jenkins Agent Connection Works (SSH Launch)

```
Jenkins Server EC2                     Jenkins Agent EC2
──────────────────                     ─────────────────
Jenkins UI configures                  Just needs:
host + SSH key  ──── SSHes in ──────►  • Java 17
                                       • Docker
Jenkins copies remoting.jar via SFTP
Jenkins runs: java -jar remoting.jar

Agent is now online in Jenkins UI.
NO token. NO manual command on agent.
NO systemd service on agent.
Jenkins manages everything over SSH.
```

---

## Table of Contents

1. [Folder Structure](#1-folder-structure)
2. [AWS EC2 & Security Groups](#2-aws-ec2--security-groups)
3. [Jenkins Server Setup](#3-jenkins-server-setup)
4. [Jenkins Initial Configuration (UI)](#4-jenkins-initial-configuration-ui)
5. [Jenkins Agent Setup](#5-jenkins-agent-setup)
6. [Add SSH Credential in Jenkins](#6-add-ssh-credential-in-jenkins)
7. [Register and Connect the Agent Node](#7-register-and-connect-the-agent-node)
8. [Create the Pipeline Job](#8-create-the-pipeline-job)
9. [Run the Pipeline](#9-run-the-pipeline)
10. [Verify Deployment](#10-verify-deployment)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Folder Structure

```
spring-petclinic/
└── jenkins-cicd-poc/
    ├── SETUP_GUIDE.md           ← this file
    ├── Dockerfile               ← multi-stage build for PetClinic
    ├── Jenkinsfile              ← declarative pipeline (3 stages)
    ├── jenkins-server-setup.sh  ← run on Jenkins Server EC2
    ├── jenkins-agent-setup.sh   ← run on Jenkins Agent EC2
    └── plugins.txt              ← required Jenkins plugins list
```

---

## 2. AWS EC2 & Security Groups

### Launch Two EC2 Instances

| | Jenkins Server | Jenkins Agent |
|---|---|---|
| Name | `jenkins-server` | `jenkins-agent` |
| Instance type | t2.micro | t2.small |
| AMI | Ubuntu 24.04 LTS | Ubuntu 24.04 LTS |
| Storage | 20 GB gp3 | 20 GB gp3 |
| Subnet | Public subnet (default VPC) | Same public subnet |
| Key pair | Same `.pem` for both | Same `.pem` for both |

### Security Groups

**Jenkins Server** (`sg-jenkins-server`):

| Port | Source | Purpose |
|------|--------|---------|
| 22 | Your IP only | SSH for setup |
| 8080 | 0.0.0.0/0 | Jenkins Web UI |

**Jenkins Agent** (`sg-jenkins-agent`):

| Port | Source | Purpose |
|------|--------|---------|
| 22 | Your IP + Jenkins Server private IP | SSH for setup + SSH launch from Jenkins |
| 8080 | 0.0.0.0/0 | PetClinic application |

> Port 50000 is NOT needed. That port is for JNLP launch. We use SSH launch.

---

## 3. Jenkins Server Setup

```bash
# From your local machine — copy the script
scp -i your-key.pem \
  jenkins-cicd-poc/jenkins-server-setup.sh \
  ubuntu@<SERVER_PUBLIC_IP>:~

# SSH into the server
ssh -i your-key.pem ubuntu@<SERVER_PUBLIC_IP>

# Run the script
chmod +x jenkins-server-setup.sh
sudo ./jenkins-server-setup.sh
```

The script installs Docker and starts Jenkins in a container.
At the end it prints the **initial admin password** and the Jenkins URL.

**Verify:**
```bash
docker ps                          # jenkins-server container should be running
docker logs jenkins-server         # look for "Jenkins is fully up and running"
```

---

## 4. Jenkins Initial Configuration (UI)

Open `http://<SERVER_PUBLIC_IP>:8080` in your browser.

**Step 1 — Unlock Jenkins**

Paste the admin password (printed by the setup script). If you need it again:
```bash
docker exec jenkins-server cat /var/jenkins_home/secrets/initialAdminPassword
```

**Step 2 — Install plugins**

Choose **"Install suggested plugins"** and wait for completion.

Then install these additional plugins:
- Manage Jenkins → Plugins → Available Plugins
- Search and install:
  - `SSH Build Agents` (plugin ID: `ssh-slaves`) ← required for SSH launch
  - `Docker Pipeline`
  - `Docker plugin`
- Restart after installing:
  ```
  http://<SERVER_PUBLIC_IP>:8080/restart
  ```

**Step 3 — Create admin user**

Fill in username / password / email → Save and Continue.

**Step 4 — Set Jenkins URL**

Set to `http://<SERVER_PUBLIC_IP>:8080` → Save and Finish.

---

## 5. Jenkins Agent Setup

SSH into the agent EC2 and run the setup script.
This installs **Java 17** and **Docker** — the only two things the agent needs.

```bash
# From your local machine — copy the script
scp -i your-key.pem \
  jenkins-cicd-poc/jenkins-agent-setup.sh \
  ubuntu@<AGENT_PUBLIC_IP>:~

# SSH into the agent
ssh -i your-key.pem ubuntu@<AGENT_PUBLIC_IP>

# Run the script
chmod +x jenkins-agent-setup.sh
sudo ./jenkins-agent-setup.sh
```

**Verify on the agent:**
```bash
java -version       # must show Java 17
docker --version    # must show Docker version
```

That is all you do on the agent machine.
**No token. No manual command. No systemd service.**
Jenkins will SSH in and start the agent process automatically.

---

## 6. Add SSH Credential in Jenkins

Jenkins needs your `.pem` key to SSH into the agent.

1. Manage Jenkins → Credentials → System → Global credentials → **Add Credentials**
2. Fill in:

| Field | Value |
|---|---|
| Kind | SSH Username with private key |
| ID | `jenkins-agent-ssh-key` |
| Description | Jenkins Agent EC2 SSH Key |
| Username | `ubuntu` |
| Private Key | Enter directly → paste the full contents of your `.pem` file |

3. Click **Create**

---

## 7. Register and Connect the Agent Node

**Step 1 — Create the node**

1. Manage Jenkins → Nodes → **New Node**
2. Node name: `petclinic-agent`
3. Type: Permanent Agent → OK

**Step 2 — Configure the node**

| Field | Value |
|---|---|
| Description | PetClinic build agent |
| Number of executors | 2 |
| Remote root directory | `/home/ubuntu/agent` |
| Labels | `petclinic-agent` |
| Usage | Use this node as much as possible |
| Launch method | **Launch agents via SSH** |
| Host | `<AGENT_PRIVATE_IP>` (use private IP — same VPC) |
| Credentials | `jenkins-agent-ssh-key` |
| Host Key Verification Strategy | Non verifying Verification Strategy |
| Availability | Keep this agent online as much as possible |

Under **Advanced**:

| Field | Value |
|---|---|
| Java Path | `/usr/bin/java` |

Leave all other fields (Environment Variables, Tool Locations, etc.) empty.

**Step 3 — Save and launch**

Click **Save** → click **"Launch agent"**

Watch the log. You should see:
```
[SSH] Authentication successful.
[SSH] Copying latest remoting.jar...
[SSH] Starting agent process: cd "/home/ubuntu/agent" && java -jar remoting.jar ...
Agent successfully connected and online
```

The node status in Manage Jenkins → Nodes will show a **green circle**.

---

## 8. Create the Pipeline Job

1. Jenkins dashboard → **New Item**
2. Name: `spring-petclinic-pipeline`
3. Type: **Pipeline** → OK
4. Under **General** tab, check **"GitHub project"** and enter:
   ```
   https://github.com/shivududeshi/AI-tools
   ```
5. Under **Build Triggers**, check **"GitHub hook trigger for GITScm polling"**
6. Under **Pipeline** section:
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: `https://github.com/shivududeshi/AI-tools.git`
   - Branch Specifier: `*/kiro-demo`
   - Script Path: `jenkins-cicd-poc/Jenkinsfile`
7. Click **Save**

No credentials needed — it's a public repository.

---

## 9. Configure GitHub Webhook (auto-trigger on merge)

This makes Jenkins automatically run the pipeline whenever a commit is pushed or
a PR is merged into the `kiro-demo` branch.

### Step 1 — Open your GitHub repo settings

Go to: `https://github.com/shivududeshi/AI-tools` → **Settings** → **Webhooks** → **Add webhook**

### Step 2 — Fill in the webhook form

| Field | Value |
|---|---|
| Payload URL | `http://<JENKINS_SERVER_PUBLIC_IP>:8080/github-webhook/` |
| Content type | `application/json` |
| Secret | *(leave blank for a public repo)* |
| Which events? | **Just the push event** |
| Active | ✅ checked |

Click **Add webhook**.

> **Important:** The trailing slash in `/github-webhook/` is required.
> GitHub must be able to reach your Jenkins server IP on port 8080 from the internet.
> Ensure your Jenkins Server security group allows port 8080 from `0.0.0.0/0`.

### Step 3 — Verify webhook delivery

On the Webhooks page, click on the webhook you just created → **Recent Deliveries**.
GitHub sends a `ping` event immediately. You should see a green ✅ with HTTP 200.
If you see a red ✗, check that `<JENKINS_SERVER_PUBLIC_IP>:8080` is publicly reachable.

### How auto-trigger works

```
Developer merges PR → kiro-demo branch
        │
        ▼
GitHub sends POST to http://<JENKINS_SERVER_IP>:8080/github-webhook/
        │
        ▼
Jenkins receives the push event
        │
        ▼
spring-petclinic-pipeline triggers automatically
        │
        ▼
Runs on petclinic-agent: Get Code → Build Artifact → Deploy Application
```

---

## 10. Run the Pipeline (First Manual Run)

After saving the job, trigger it once manually to confirm everything works
before relying on the webhook.

Click **"Build Now"** on the `spring-petclinic-pipeline` job.

The 3 stages will run on `petclinic-agent`:

```
┌─────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│  Get Code   │───►│  Build Artifact  │───►│ Deploy Application  │
│             │    │                  │    │                     │
│ git clone   │    │ mvn clean package│    │ docker build        │
│ from GitHub │    │ -DskipTests      │    │ docker run :8080    │
│ kiro-demo   │    │ archives JAR     │    │ health check loop   │
└─────────────┘    └──────────────────┘    └─────────────────────┘
```

Click any stage box in **Stage View** to see its console output.

---

## 11. Verify Deployment

**Check the application in your browser:**
```
http://<AGENT_PUBLIC_IP>:8080
```

**Check via curl:**
```bash
curl http://<AGENT_PUBLIC_IP>:8080/actuator/health
# Expected: {"status":"UP"}
```

**Check the running container on the agent:**
```bash
ssh -i your-key.pem ubuntu@<AGENT_PUBLIC_IP>

docker ps
# Should show: petclinic-container   0.0.0.0:8080->8080/tcp

docker logs petclinic-container
```

**Test the auto-trigger:**
```bash
# Push any commit to kiro-demo branch
git checkout kiro-demo
echo "# trigger" >> README.md
git add README.md
git commit -m "test: trigger Jenkins webhook"
git push origin kiro-demo
```
Within a few seconds, Jenkins should start a new build automatically.

---

## 11. Troubleshooting

### Agent fails with "java: command not found"
```bash
# SSH into agent and install Java
sudo apt-get install -y openjdk-17-jdk-headless
java -version
```
Then re-launch the agent from Jenkins UI.

### Agent fails with "Permission denied" creating directory
The Remote root directory field has a path that `ubuntu` can't write to.
Change it to `/home/ubuntu/agent` in the node config.

### Agent connects then immediately disconnects
```bash
# Check Jenkins server can reach agent port 22
# From Jenkins server EC2:
ssh -i your-key.pem ubuntu@<AGENT_PRIVATE_IP>
```
If that fails, check the agent security group allows port 22 from the server's private IP.

### Docker build fails — "permission denied while trying to connect to Docker"
```bash
# On agent: verify ubuntu is in docker group
groups ubuntu   # should include 'docker'

# If missing:
sudo usermod -aG docker ubuntu
# Then log out and back in, or run:
newgrp docker
```
Re-launch the agent from Jenkins UI after fixing.

### PetClinic port 8080 already in use
```bash
# On agent:
sudo lsof -i :8080
docker stop petclinic-container
docker rm petclinic-container
```
Re-run the pipeline.

### Jenkins container on server restarts and loses config
The `/var/jenkins_home` volume persists all config. After EC2 reboot:
```bash
docker ps   # jenkins-server should auto-restart (restart=unless-stopped)
# If not:
docker start jenkins-server
```
