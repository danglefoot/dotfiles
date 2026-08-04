#!/usr/bin/env bash
# ============================================================================
# Phase 1: system-level installs (requires sudo)
#   - apt packages mapped from the Brewfile
#   - gh + kubectl official apt repos
#   - neovim 0.11+ from official tarball (Debian ships 0.10.4, too old)
#   - bat/fd shims (Debian names them batcat/fdfind)
#   - register fish as a valid login shell
# Idempotent: safe to re-run.
# ============================================================================
set -euo pipefail

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }

export DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
log "Bootstrapping prerequisites (curl, gnupg, ca-certificates)"
# ---------------------------------------------------------------------------
# These are needed to add the apt repos below, so they cannot wait for the
# main package loop. Minimal Debian images ship none of them.
sudo apt-get update -qq
sudo apt-get install -y -qq curl gnupg ca-certificates apt-transport-https

# ---------------------------------------------------------------------------
log "Adding third-party apt repos (gh, kubectl)"
# ---------------------------------------------------------------------------
sudo install -m 0755 -d /etc/apt/keyrings

# GitHub CLI
if [ ! -f /etc/apt/keyrings/githubcli.gpg ]; then
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/githubcli.gpg
fi
sudo chmod a+r /etc/apt/keyrings/githubcli.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli.gpg] https://cli.github.com/packages stable main" \
  | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null

# Docker Engine (proc-forge development)
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
  curl -fsSL https://download.docker.com/linux/debian/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
fi
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

# Kubernetes (kubectl) — v1.34 stable channel
K8S_MINOR="v1.34"
if [ ! -f /etc/apt/keyrings/kubernetes.gpg ]; then
  curl -fsSL "https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/deb/Release.key" \
    | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg
fi
sudo chmod a+r /etc/apt/keyrings/kubernetes.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null

# ---------------------------------------------------------------------------
log "apt update"
# ---------------------------------------------------------------------------
sudo apt-get update -qq

# ---------------------------------------------------------------------------
log "Installing apt packages"
# ---------------------------------------------------------------------------
# Core toolchain + everything from the Brewfile that maps cleanly to Debian.
PKGS=(
  # build / base
  build-essential pkg-config ca-certificates gnupg apt-transport-https
  curl wget git unzip zip xz-utils file
  # shell + multiplexer + dotfile management
  fish tmux stow
  # cli parity with Brewfile
  bat eza fd-find fzf zoxide ripgrep jq tree htop ncdu
  lazygit nmap lynx xclip
  # languages / libs proc-forge or nvim tooling may want
  python3 python3-venv python3-pip
  libpq-dev
  luarocks
  # .NET runtime deps — this minimal image ships neither, and dotnet
  # hard-aborts at startup without ICU (System.Globalization).
  libicu-dev libssl-dev zlib1g
  # JetBrains Remote Development (Rider) backend deps. It runs headless (no
  # desktop needed) but still links these X client + font libs even when
  # nothing is displayed; without them the backend fails to start.
  libfreetype6 libfontconfig1 libxext6 libxrender1 libxtst6 libxi6
  libx11-6 libxrandr2
  # gh + kubectl from the repos added above
  gh kubectl
)

# Install one-by-one tolerant of any package missing on this release.
MISSING=()
for p in "${PKGS[@]}"; do
  if ! sudo apt-get install -y -qq "$p" >/dev/null 2>&1; then
    MISSING+=("$p")
  fi
done
if [ ${#MISSING[@]} -gt 0 ]; then
  printf '  \033[33m! could not install:\033[0m %s\n' "${MISSING[*]}"
fi

# ---------------------------------------------------------------------------
log "Installing Docker Engine"
# ---------------------------------------------------------------------------
sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
# Run docker as $USER without sudo; membership takes effect on next login
# (or `newgrp docker` in the current shell).
sudo usermod -aG docker "$USER"
sudo systemctl enable --now docker

# ---------------------------------------------------------------------------
log "Installing Neovim (official tarball, 0.11+)"
# ---------------------------------------------------------------------------
NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
tmp="$(mktemp -d)"
curl -fsSL "$NVIM_URL" -o "$tmp/nvim.tar.gz"
sudo rm -rf /opt/nvim
sudo mkdir -p /opt/nvim
sudo tar -xzf "$tmp/nvim.tar.gz" -C /opt/nvim --strip-components=1
sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
rm -rf "$tmp"

# ---------------------------------------------------------------------------
log "Creating bat/fd shims (Debian installs them as batcat/fdfind)"
# ---------------------------------------------------------------------------
[ -x /usr/bin/batcat ] && sudo ln -sf /usr/bin/batcat /usr/local/bin/bat
[ -x /usr/bin/fdfind ] && sudo ln -sf /usr/bin/fdfind /usr/local/bin/fd

# ---------------------------------------------------------------------------
log "Registering fish as a login shell"
# ---------------------------------------------------------------------------
FISH_PATH="$(command -v fish)"
grep -qxF "$FISH_PATH" /etc/shells || echo "$FISH_PATH" | sudo tee -a /etc/shells >/dev/null

# ---------------------------------------------------------------------------
log "Verification"
# ---------------------------------------------------------------------------
for c in fish nvim gh kubectl stow bat fd eza fzf zoxide rg jq lazygit tmux; do
  printf '  %-10s ' "$c"
  if command -v "$c" >/dev/null 2>&1; then
    "$c" --version 2>/dev/null | head -1
  else
    echo "MISSING"
  fi
done

printf '\n\033[1;32m✓ Phase 1 complete.\033[0m Your login shell is still bash — that gets switched at the end.\n'
