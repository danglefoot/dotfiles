#!/usr/bin/env bash
# ============================================================================
# Phase 2: user-local installs (NO sudo) -> ~/.local/bin
#   starship, sesh, k9s, helm, flux, kubeseal, talosctl, dotnet SDK, tldr
# Idempotent: safe to re-run.
# ============================================================================
set -uo pipefail

BIN="$HOME/.local/bin"
mkdir -p "$BIN"
export PATH="$BIN:$PATH"

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
fail() { printf '  \033[31m✗\033[0m %s\n' "$*"; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Fetch a GitHub release asset matching a pattern, extract a binary from it.
# gh_bin <owner/repo> <asset-glob> <binary-name-inside-archive>
gh_bin() {
  local repo="$1" glob="$2" binname="$3"
  local url
  url="$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
        | grep -o "\"browser_download_url\": *\"[^\"]*\"" \
        | cut -d'"' -f4 | grep -E "$glob" | head -1)"
  if [ -z "$url" ]; then fail "$repo: no asset matching $glob"; return 1; fi
  local d="$tmp/$binname"; mkdir -p "$d"
  curl -fsSL "$url" -o "$d/archive"
  case "$url" in
    *.tar.gz|*.tgz) tar -xzf "$d/archive" -C "$d" ;;
    *.zip)          unzip -qo "$d/archive" -d "$d" ;;
    *)              mv "$d/archive" "$d/$binname" ;;
  esac
  local found
  found="$(find "$d" -type f -name "$binname" | head -1)"
  if [ -z "$found" ]; then fail "$repo: $binname not found in archive"; return 1; fi
  install -m 0755 "$found" "$BIN/$binname"
  ok "$binname -> $BIN/$binname"
}

# ---------------------------------------------------------------------------
log "starship (prompt)"
# ---------------------------------------------------------------------------
if curl -fsSL https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$BIN" >/dev/null 2>&1; then
  ok "starship"
else fail "starship"; fi

# ---------------------------------------------------------------------------
log "Kubernetes tooling"
# ---------------------------------------------------------------------------
# helm
if curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o "$tmp/helm.sh" \
   && HELM_INSTALL_DIR="$BIN" USE_SUDO=false bash "$tmp/helm.sh" --no-sudo >/dev/null 2>&1; then
  ok "helm"
else fail "helm"; fi

# talosctl
if curl -fsSL https://talos.dev/install -o "$tmp/talos.sh" 2>/dev/null \
   && sed -i 's|/usr/local/bin|'"$BIN"'|g' "$tmp/talos.sh" 2>/dev/null \
   && bash "$tmp/talos.sh" >/dev/null 2>&1; then
  ok "talosctl"
else
  gh_bin "siderolabs/talos" "talosctl-linux-amd64$" "talosctl-linux-amd64" \
    && mv -f "$BIN/talosctl-linux-amd64" "$BIN/talosctl" && ok "talosctl (fallback)"
fi

gh_bin "derailed/k9s"            "k9s_Linux_amd64\.tar\.gz$"        "k9s"
gh_bin "fluxcd/flux2"            "flux_.*_linux_amd64\.tar\.gz$"    "flux"
gh_bin "bitnami-labs/sealed-secrets" "kubeseal-.*-linux-amd64\.tar\.gz$" "kubeseal"

# ---------------------------------------------------------------------------
log "Talos secret tooling (talhelper, sops, age)"
# ---------------------------------------------------------------------------
# Needed to render talosconfig from talconfig.yaml + sops-encrypted secrets.
gh_bin "budimanjojo/talhelper" "talhelper_linux_amd64\.tar\.gz$"   "talhelper"
gh_bin "getsops/sops"          "sops-.*\.linux\.amd64$"            "sops"
# age ships age + age-keygen in one tarball; extract both.
if url="$(curl -fsSL https://api.github.com/repos/FiloSottile/age/releases/latest \
      | grep -o '"browser_download_url": *"[^"]*"' | cut -d'"' -f4 \
      | grep -E 'age-.*-linux-amd64\.tar\.gz$' | head -1)" && [ -n "$url" ]; then
  d="$tmp/age"; mkdir -p "$d"; curl -fsSL "$url" -o "$d/a.tgz"; tar -xzf "$d/a.tgz" -C "$d"
  install -m 0755 "$(find "$d" -type f -name age | head -1)" "$BIN/age" && ok "age -> $BIN/age"
  install -m 0755 "$(find "$d" -type f -name age-keygen | head -1)" "$BIN/age-keygen" && ok "age-keygen -> $BIN/age-keygen"
else fail "age"; fi

# ---------------------------------------------------------------------------
log "sesh (tmux session manager)"
# ---------------------------------------------------------------------------
gh_bin "joshmedeski/sesh" "sesh_Linux_x86_64\.tar\.gz$" "sesh"

# ---------------------------------------------------------------------------
log ".NET SDK"
# ---------------------------------------------------------------------------
if curl -fsSL https://dot.net/v1/dotnet-install.sh -o "$tmp/dotnet-install.sh" \
   && bash "$tmp/dotnet-install.sh" --channel LTS --install-dir "$HOME/.dotnet" >/dev/null 2>&1; then
  ln -sf "$HOME/.dotnet/dotnet" "$BIN/dotnet"
  ok "dotnet SDK (LTS) -> ~/.dotnet"
else fail "dotnet"; fi

# ---------------------------------------------------------------------------
log "tldr (via pip, not in trixie apt)"
# ---------------------------------------------------------------------------
pip install --user --break-system-packages -q tldr >/dev/null 2>&1 && ok "tldr" || fail "tldr"

# ---------------------------------------------------------------------------
log "Verification"
# ---------------------------------------------------------------------------
for c in starship helm talosctl k9s flux kubeseal talhelper sops age sesh dotnet tldr; do
  printf '  %-10s ' "$c"
  if command -v "$c" >/dev/null 2>&1; then
    "$c" --version 2>/dev/null | head -1 || echo "(installed)"
  else
    echo "MISSING"
  fi
done

printf '\n\033[1;32m✓ Phase 2 complete.\033[0m\n'
