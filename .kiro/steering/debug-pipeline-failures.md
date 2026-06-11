# Debug Pipeline Failures

## Purpose

This steering document defines the standard workflow Kiro must follow when diagnosing CI/CD pipeline failures.

The objective is to identify the root cause quickly, gather supporting evidence, and recommend corrective actions using available MCP servers and Kiro Powers.

---

# Primary Power

When a pipeline-related issues are reported, Kiro should first activate:

Power:
cicd-pipeline-power

This power is responsible for:

* Jenkins build analysis
* Console log retrieval
* Pipeline stage analysis
* GitHub integration
* Webhook validation
* Deployment troubleshooting
* Agent diagnostics

---

# Failure Investigation Workflow

Whenever a user reports:

* Build failed
* Deployment failed
* Jenkins job failed
* GitHub webhook not triggering
* Container not starting
* Health check failure

Kiro should follow the workflow below.

---

## Step 1 - Gather Context

Collect:

* Jenkins job name
* Build number
* Repository
* Branch
* Trigger source
* Timestamp

If build number is not supplied:

Retrieve latest failed build.

---

## Step 2 - Determine Failure Stage

Identify the stage where the pipeline failed.

Possible stages:

1. Get Code
2. Build Artifact
3. Deploy Application

Never suggest fixes before identifying the failing stage.

---

## Step 3 - Collect Evidence

Retrieve:

* Console logs
* Build metadata
* Stage execution logs
* Docker logs (if deployment stage failed)
* Agent status

Evidence must be included in every diagnosis.

---

# Failure Classification

## Category: Git Checkout Failure

Typical Symptoms:

* Repository not found
* Authentication failure
* Branch not found

Check:

* Repository URL
* Branch name
* GitHub credentials
* Webhook delivery status

Recommended MCP Usage:

* github MCP
* jenkins MCP

---

## Category: Maven Build Failure

Typical Symptoms:

* Compilation error
* Missing dependency
* Plugin failure

Check:

* pom.xml
* Dependency versions
* Maven output

Recommended Power:

* cicd-pipeline-power

Expected Output:

* Root cause
* Failed module
* Recommended code fix

---

## Category: Test Failure

Typical Symptoms:

* Unit tests failed
* Integration tests failed

Check:

* Surefire reports
* Test logs

Expected Response:

* Failed test names
* Failure reason
* Suggested fix

---

## Category: Docker Build Failure

Typical Symptoms:

* Docker build exits non-zero
* Dockerfile syntax errors

Check:

* Dockerfile
* Docker build logs

Expected Response:

* Failed Docker instruction
* Suggested Dockerfile correction

---

## Category: Container Startup Failure

Typical Symptoms:

* Container exits immediately
* CrashLoop
* JVM startup error

Check:

docker logs

Investigate:

* Missing environment variables
* Port conflicts
* Application startup exceptions

Expected Response:

* Root cause
* Relevant log excerpts
* Corrective action

---

## Category: Health Check Failure

Typical Symptoms:

* /actuator/health never returns HTTP 200
* Deployment timeout

Check:

* Application startup logs
* Database connectivity
* Port mappings
* Health endpoint configuration

Expected Response:

* Why health check failed
* Required configuration changes

---

## Category: Agent Failure

Typical Symptoms:

* Node offline
* Build stuck in queue
* Workspace unavailable

Check:

* Agent online status
* Executor availability
* Disk space
* Agent logs

Expected Response:

* Agent diagnosis
* Recovery steps

---

## Category: Webhook Failure

Typical Symptoms:

* Push event does not trigger Jenkins

Check:

GitHub:

* Webhook exists
* Delivery successful

Jenkins:

* github-webhook endpoint reachable
* Job configured with githubPush()

Expected Response:

* Missing configuration
* Required fixes

---

# Deployment Diagnostics

When deployment issues are reported:

Always collect:

1. Docker image tag
2. Container status
3. Container logs
4. Health check status

Verify:

* Image built successfully
* Container started successfully
* Port mapping correct
* Health endpoint available

Never assume deployment succeeded without validation.

---

# Root Cause Analysis Format

All failure investigations should produce:

## Summary

Short description of failure.

## Failure Stage

Get Code / Build Artifact / Deploy Application

## Root Cause

Technical explanation.

## Evidence

Relevant log entries.

## Recommended Fix

Specific actions.

## Prevention

Recommended Jenkinsfile, Dockerfile, or process improvements.

---

# CI/CD Improvement Recommendations

When recurring failures are detected, recommend:

* SonarQube integration
* Trivy image scanning
* Automated rollback
* Improved health checks
* Build caching
* Dependency management improvements
* Additional monitoring

---

# Team Standards

Repository:
shivududeshi/AI-tools

Branch:
kiro-demo

Agent:
petclinic-agent

Pipeline Stages:

1. Get Code
2. Build Artifact
3. Deploy Application

Build Command:

./mvnw clean package -DskipTests

Health Endpoint:

/actuator/health

Container:

petclinic-container

Port:

8080

Always validate recommendations against team standards before suggesting changes.

---

# Example Requests

The latest build failed. Diagnose the issue.

Why did build #42 fail?

The deployment stage timed out. Investigate.

The container is restarting continuously.

GitHub pushes are not triggering Jenkins.

Review the latest failed build and provide a root cause analysis.

Check whether the Jenkins agent is healthy.
