# syntax=docker/dockerfile:1.7

FROM node:22-bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TERM=xterm-256color \
    PYTHONUNBUFFERED=1 \
    PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright \
    PLAYWRIGHT_MCP_BROWSER=chromium \
    PAGER=cat \
    GIT_PAGER=cat

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# -------------------------------------------------------------------
# System packages
# -------------------------------------------------------------------

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    bash-completion \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    dnsutils \
    fd-find \
    file \
    git \
    git-lfs \
    gh \
    htop \
    iproute2 \
    iputils-ping \
    jq \
    less \
    lsof \
    make \
    nano \
    netcat-openbsd \
    openssh-client \
    openssh-server \
    pkg-config \
    procps \
    python3 \
    python3-dev \
    python3-pip \
    python3-venv \
    ripgrep \
    rsync \
    shellcheck \
    sqlite3 \
    strace \
    sudo \
    tmux \
    tree \
    unzip \
    vim-tiny \
    wget \
    zip \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && git lfs install --system \
    && mkdir -p /run/sshd \
    && rm -rf /var/lib/apt/lists/*

# -------------------------------------------------------------------
# Package manager
# -------------------------------------------------------------------

RUN npm install -g pnpm@latest \
    && npm cache clean --force

# -------------------------------------------------------------------
# AI Agents
# -------------------------------------------------------------------

RUN npm install -g @openai/codex@latest

RUN npm install -g @anthropic-ai/claude-code@latest

RUN npm install -g @google/gemini-cli@latest

RUN npm install -g @playwright/cli@latest

RUN npm cache clean --force

# -------------------------------------------------------------------
# Chromium + Linux browser dependencies
# -------------------------------------------------------------------

RUN playwright-cli install-browser --with-deps \
    && chmod -R a+rX /opt/ms-playwright \
    && rm -rf /var/lib/apt/lists/*

# -------------------------------------------------------------------
# Agent user
#
# node:22-bookworm-slim enthält bereits:
#   user: node
#   UID:  1000
#   GID:  1000
#
# Wir benennen diesen Benutzer einfach in "agent" um.
# -------------------------------------------------------------------

RUN groupmod -n agent node \
    && usermod \
        -l agent \
        -d /home/agent \
        -m \
        node \
    && passwd -d agent \
    && mkdir -p \
        /workspace \
        /home/agent/.ssh \
        /var/lib/agent-ssh \
    && chmod 700 /home/agent/.ssh \
    && chown -R agent:agent \
        /home/agent \
        /workspace

# -------------------------------------------------------------------
# SSH configuration
# -------------------------------------------------------------------

RUN cat > /etc/ssh/sshd_config.d/agent.conf <<'EOF'
PermitRootLogin no

AllowUsers agent

PubkeyAuthentication yes
AuthenticationMethods publickey

PasswordAuthentication no
PermitEmptyPasswords no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no

X11Forwarding no

AllowTcpForwarding yes
GatewayPorts no

ClientAliveInterval 60
ClientAliveCountMax 3

UseDNS no

HostKey /var/lib/agent-ssh/ssh_host_ed25519_key
EOF

# -------------------------------------------------------------------
# Image-provided skills and shared agent instructions
# -------------------------------------------------------------------

COPY skills/ /opt/agent/skills/
COPY --chmod=755 scripts/agent-link-skills.sh /usr/local/bin/agent-link-skills

# Use the CLI's installer to obtain the matching skill, then keep its
# files outside the persistent home volume. Reserve this name for Playwright.
RUN playwright-cli install --skills=agents -g \
    && test ! -e /opt/agent/skills/playwright-cli \
    && mv /root/.agents/skills/playwright-cli /opt/agent/skills/playwright-cli \
    && rmdir /root/.agents/skills /root/.agents \
    && test -f /opt/agent/skills/playwright-cli/SKILL.md \
    && chmod -R a+rX /opt/agent/skills

# Seed links for fresh home volumes; the entrypoint also handles existing ones.
RUN runuser -u agent -- /usr/local/bin/agent-link-skills

# -------------------------------------------------------------------
# Entrypoint
# -------------------------------------------------------------------

RUN cat > /usr/local/bin/agent-entrypoint <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

mkdir -p \
    /run/sshd \
    /home/agent/.ssh \
    /var/lib/agent-ssh

chmod 700 /home/agent/.ssh
chown agent:agent /home/agent/.ssh

# Require SSH public key
if [[ -z "${SSH_AUTHORIZED_KEYS:-}" ]]; then
    echo "ERROR: SSH_AUTHORIZED_KEYS is not set."
    exit 1
fi

# Volumes are mounted now, so existing homes also receive the image links.
runuser -u agent -- /usr/local/bin/agent-link-skills

printf '%s\n' "${SSH_AUTHORIZED_KEYS}" \
    > /home/agent/.ssh/authorized_keys

chmod 600 /home/agent/.ssh/authorized_keys
chown agent:agent /home/agent/.ssh/authorized_keys

# Persistent SSH host key
if [[ ! -f /var/lib/agent-ssh/ssh_host_ed25519_key ]]; then
    ssh-keygen \
        -q \
        -t ed25519 \
        -N '' \
        -f /var/lib/agent-ssh/ssh_host_ed25519_key
fi

chmod 600 /var/lib/agent-ssh/ssh_host_ed25519_key
chmod 644 /var/lib/agent-ssh/ssh_host_ed25519_key.pub

# Validate SSH configuration
/usr/sbin/sshd -t

# SSH becomes main container process
exec /usr/sbin/sshd -D -e
EOF

RUN chmod +x /usr/local/bin/agent-entrypoint

# -------------------------------------------------------------------
# Sanity checks
# -------------------------------------------------------------------

RUN node --version \
    && npm --version \
    && python3 --version \
    && git --version \
    && codex --version \
    && claude --version \
    && gemini --version \
    && playwright-cli --version

WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/agent-entrypoint"]
