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
scripts/agent-link-skills.sh
skills/agents.md
skills/example-workspace-overview/SKILL.md
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

## Image-provided Skills and Instructions

The image contains the Playwright CLI skill and this repository's `skills/`
directory under `/opt/agent/skills`:

```text
/opt/agent/skills/
├── agents.md
├── example-workspace-overview/
│   └── SKILL.md
└── playwright-cli/
    ├── SKILL.md
    └── references/
```

Each immediate subdirectory containing a `SKILL.md` is linked into both
`~/.agents/skills/` (Codex and Gemini) and `~/.claude/skills/` (Claude Code).
The Playwright files are supplied by the CLI installed in the same image.
The name `playwright-cli` is reserved; put additional skills in their own
directories under `skills/`.

The shared `skills/agents.md` is linked using the filenames each CLI reads:

| Tool | Home path | Image source |
| --- | --- | --- |
| Codex | `~/.codex/AGENTS.md` | `/opt/agent/skills/agents.md` |
| Claude Code | `~/.claude/CLAUDE.md` | `/opt/agent/skills/agents.md` |
| Gemini CLI | `~/.gemini/GEMINI.md` | `/opt/agent/skills/agents.md` |

These are the CLIs' default home locations; custom configuration-home overrides
are not configured by this image. The source filename is lowercase `agents.md`;
the links use the required uppercase names. See the official documentation for
[Codex instructions](https://learn.chatgpt.com/docs/agent-configuration/agents-md),
[Claude instructions](https://code.claude.com/docs/en/memory), and
[Gemini instructions](https://geminicli.com/docs/cli/gemini-md/).

The entrypoint creates the links after volumes are mounted, so existing home
volumes work too. Existing files or directories with the same names are moved
once to `~/.local/state/agent/skill-backups/migration.*/`, preserving their
relative paths, and the backup paths are logged. Those previous instructions
and skills are retained as backups but are no longer loaded at those locations.
Unrelated personal skills and agent settings are left in place. Repeated starts
reuse correct links, and links to bundled skills removed from the image are
cleaned up automatically.

Edit bundled skills and shared instructions in this repository and rebuild the
image. `/opt/agent/skills` must not be covered by a volume or bind mount: the
symlinks in the persistent home must resolve to files from the current image.
No skill downloads, file synchronization, or version comparisons run at startup.

To rebuild with the latest CLI packages and recreate the containers:

```bash
docker compose build --pull --no-cache agent
docker compose up -d --force-recreate agent netbird
```

NetBird is recreated alongside the agent because they share a network namespace.
A plain restart does not adopt a newly built image. Existing home and workspace
volumes, including project files and logins, are retained.

For changes only to `skills/`, a cached `docker compose build agent` is sufficient
before recreating the containers. Try the example skill by asking an agent for
an overview of the projects in `/workspace`.

Run the link migration and update checks locally with:

```bash
python3 -m unittest discover -s tests -v
shellcheck scripts/agent-link-skills.sh
```

## Stop the Runtime

```bash
docker compose down
```

Persistent volumes are kept unless explicitly removed.
