# AI Agent Container Runtime

A Docker-based runtime environment for running AI coding agents in an isolated, remotely accessible container.

Included:

* OpenAI Codex CLI
* Anthropic Claude Code
* Google Gemini CLI
* Playwright + Chromium
* SSH access
* NetBird for private remote networking
* Node.js 22
* Python 3
* Git / GitHub CLI
* Persistent workspace and agent configuration

## Architecture

The setup consists of two containers:

* `agent` – runs the AI tools, browser, SSH server, and workspace
* `netbird` – provides private remote network access

Both containers share the same network namespace. This allows services running inside the agent container to be accessed directly through the NetBird IP address.

## Requirements

* Docker
* Docker Compose
* `/dev/net/tun` available on the Docker host
* A NetBird account and setup key
* An SSH public key

Check TUN availability:

```bash
ls -l /dev/net/tun
```

## Environment Variables

Required:

```env
AGENT_HOSTNAME=ai-agent-01
NB_SETUP_KEY=...
SSH_AUTHORIZED_KEYS=ssh-ed25519 AAAA...
```

Optional AI provider credentials:

```env
OPENAI_API_KEY=...
ANTHROPIC_API_KEY=...
GEMINI_API_KEY=...
```

## Deployment

The repository contains:

```text
Dockerfile
docker-compose.yml
README.md
```

Start the runtime with:

```bash
docker compose up -d --build
```

Check the running containers:

```bash
docker compose ps
```

## SSH Access

Your local machine must also be connected to the same NetBird network.

Connect using the NetBird IP:

```bash
ssh agent@<NETBIRD-IP>
```

Or, if NetBird DNS is enabled:

```bash
ssh agent@ai-agent-01
```

Inside the container, the AI tools are available directly:

```bash
codex
claude
gemini
playwright-cli
```

## Accessing Web Applications

Applications must listen on `0.0.0.0` to be reachable through NetBird.

Example:

```bash
npm run dev -- --host 0.0.0.0
```

If the application runs on port `3000`, access it through:

```text
http://<NETBIRD-IP>:3000
```

The same applies to other ports such as:

```text
http://<NETBIRD-IP>:8080
http://<NETBIRD-IP>:8000
https://<NETBIRD-IP>:443
```

No public Docker port mapping is required when accessing services exclusively through NetBird.

## Persistent Data

The Docker Compose setup persists:

* `/home/agent`
* `/workspace`
* SSH host keys
* NetBird configuration

This keeps repositories, agent settings, authentication state, and NetBird connectivity available across container rebuilds and restarts.

## Stop the Runtime

```bash
docker compose down
```

Persistent volumes are kept unless explicitly removed.
