# syntax=docker/dockerfile:1.7

FROM node:22-bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive
ARG AGENT_UID=1000
ARG AGENT_GID=1000

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
# Node package managers + AI agents
# -------------------------------------------------------------------

RUN npm install -g \
    pnpm@latest \
    yarn@latest \
    @openai/codex@latest \
    @anthropic-ai/claude-code@latest \
    @google/gemini-cli@latest \
    @playwright/cli@latest \
    && npm cache clean --force

# -------------------------------------------------------------------
# Chromium + Linux browser dependencies
# -------------------------------------------------------------------

RUN playwright-cli install-browser --with-deps \
    && chmod -R a+rX /opt/ms-playwright \
    && rm -rf /var/lib/apt/lists/*

# -------------------------------------------------------------------
# Agent user
# -------------------------------------------------------------------

RUN groupadd --gid "${AGENT_GID}" agent \
    && useradd \
        --uid "${AGENT_UID}" \
        --gid "${AGENT_GID}" \
        --create-home \
        --shell /bin/bash \
        agent \
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
# Playwright skills
# -------------------------------------------------------------------

USER agent
WORKDIR /workspace

RUN playwright-cli install --skills -g \
    && playwright-cli install --skills=agents -g

USER root

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
