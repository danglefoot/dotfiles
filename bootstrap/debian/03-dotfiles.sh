#!/usr/bin/env bash
# ============================================================================
# Phase 3: dotfiles, dev repos, shell switch (NO sudo except chsh)
#   - clone dotfiles (~/.dotfiles) with nvim submodule, over SSH
#   - stow all configs via the repo's own setup.sh
#   - clone dev repos into ~/src
#   - switch the nvim submodule + dev repos to SSH remotes (push access)
#   - chsh the login shell to fish
# Prereqs: phases 01 + 02 done, and `gh auth login` completed (SSH protocol).
# Idempotent: safe to re-run.
# ============================================================================
set -uo pipefail

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
fail() { printf '  \033[31m✗\033[0m %s\n' "$*"; }

GH_USER="danglefoot"
DOTFILES="$HOME/.dotfiles"
SRC="$HOME/src"
DEV_REPOS=(talos-homelab proc-forge)

# ---------------------------------------------------------------------------
log "Preflight: gh auth + SSH to GitHub"
# ---------------------------------------------------------------------------
if ! gh auth status >/dev/null 2>&1; then
  fail "gh not authenticated — run: gh auth login  (choose SSH)"; exit 1
fi
# Pin GitHub host keys from the cert-verified meta API (no blind keyscan).
mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
if ! grep -q '^github.com ' "$HOME/.ssh/known_hosts" 2>/dev/null; then
  curl -fsSL https://api.github.com/meta \
    | jq -r '.ssh_keys[] | "github.com \(.)"' >> "$HOME/.ssh/known_hosts"
  chmod 600 "$HOME/.ssh/known_hosts"; ok "pinned GitHub host keys"
fi
# Ensure this box's key is registered (idempotent: gh errors if already added).
if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
  gh ssh-key add "$HOME/.ssh/id_ed25519.pub" --title "$(hostname)" --type authentication 2>/dev/null \
    && ok "uploaded SSH key ($(hostname))" || true
fi
if ssh -T -o StrictHostKeyChecking=yes git@github.com 2>&1 | grep -q "successfully authenticated"; then
  ok "SSH push access OK"
else
  fail "SSH auth to GitHub failed"; exit 1
fi

# ---------------------------------------------------------------------------
log "Cloning dotfiles -> $DOTFILES"
# ---------------------------------------------------------------------------
if [ -d "$DOTFILES/.git" ]; then
  ok "already cloned"
else
  git clone --recurse-submodules "git@github.com:${GH_USER}/dotfiles.git" "$DOTFILES" \
    && ok "cloned" || { fail "clone failed"; exit 1; }
fi
# Force the nvim submodule onto SSH (it's registered as https in .gitmodules).
if [ -d "$DOTFILES/nvim/.config/nvim/.git" ] || [ -f "$DOTFILES/nvim/.config/nvim/.git" ]; then
  git -C "$DOTFILES" submodule set-url nvim/.config/nvim "git@github.com:${GH_USER}/nvim.git" >/dev/null 2>&1
  git -C "$DOTFILES" submodule sync --quiet
  git -C "$DOTFILES/nvim/.config/nvim" remote set-url origin "git@github.com:${GH_USER}/nvim.git"
  ok "nvim submodule -> SSH"
fi

# ---------------------------------------------------------------------------
log "Stowing configs (via dotfiles/setup.sh)"
# ---------------------------------------------------------------------------
( cd "$DOTFILES" && bash setup.sh ) >/dev/null 2>&1 && ok "stowed" || fail "setup.sh had errors (re-run manually to see)"

# ---------------------------------------------------------------------------
log "gh extensions"
# ---------------------------------------------------------------------------
GH_EXTENSIONS=(dlvhdr/gh-dash)
for ext in "${GH_EXTENSIONS[@]}"; do
  if gh extension list | grep -q "$ext"; then
    ok "$ext already installed"
  else
    gh extension install "$ext" >/dev/null 2>&1 && ok "$ext installed" || fail "$ext install failed"
  fi
done

# ---------------------------------------------------------------------------
log "Cloning dev repos -> $SRC"
# ---------------------------------------------------------------------------
mkdir -p "$SRC"
for r in "${DEV_REPOS[@]}"; do
  if [ -d "$SRC/$r/.git" ]; then
    ok "$r already cloned"
  else
    git clone "git@github.com:${GH_USER}/${r}.git" "$SRC/$r" >/dev/null 2>&1 \
      && ok "$r" || fail "$r clone failed"
  fi
done

# ---------------------------------------------------------------------------
log "Switching login shell to fish"
# ---------------------------------------------------------------------------
FISH_PATH="$(command -v fish)"
if [ "$(getent passwd "$USER" | cut -d: -f7)" = "$FISH_PATH" ]; then
  ok "login shell already fish"
elif [ -n "$FISH_PATH" ] && grep -qxF "$FISH_PATH" /etc/shells; then
  chsh -s "$FISH_PATH" && ok "login shell -> fish (log out/in to take effect)" \
    || fail "chsh failed (run manually: chsh -s $FISH_PATH)"
else
  fail "fish not in /etc/shells — re-run 01-system.sh"
fi

printf '\n\033[1;32m✓ Phase 3 complete.\033[0m\n'
cat <<'EOF'

  Manual follow-ups (cannot be scripted safely):
    • talos-homelab secrets: drop your age private key at
        ~/.config/sops/age/keys.txt   (matches age14c97rz… in .sops.yaml)
      then: cd ~/src/talos-homelab && talhelper genconfig
    • Verify fish starts clean, then commit the config.fish portability
      fixes:  cd ~/.dotfiles && git add fish && git commit && git push
EOF
