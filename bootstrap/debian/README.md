# Debian devbox bootstrap

Three idempotent phases (the Debian analogue of the Brewfile):

1. `01-system.sh` — apt packages, third-party repos (gh, kubectl, Docker),
   neovim tarball. Requires sudo. Run WITHOUT sudo (it sudos internally) —
   running the whole script under sudo makes `$USER` root and, e.g., puts
   root instead of you in the docker group.
2. `02-userland.sh` — user-level toolchains (fnm/node, dotnet, ...).
3. `03-dotfiles.sh` — stows configs via ../../setup.sh, installs gh
   extensions, clones dev repos, switches shell to fish. Needs `gh auth
   login` (SSH) first.

Fresh-machine knot: you need git + a GitHub credential before this repo can
be cloned. Minimal pre-step on a blank box:

    sudo apt update && sudo apt install -y git curl
    # then either an SSH key or a PAT to clone this repo, then run 01 → 03.

`~/setup` on the devbox is a symlink here.
