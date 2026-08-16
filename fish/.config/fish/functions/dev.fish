function dev --description "ssh to devbox and attach tmux, following macOS appearance"
    # Remote tmux + nvim have no system appearance to follow; on Linux
    # github-theme.sh persists a light|dark mode file that both read. Push the
    # Mac's current mode on connect, then keep it in sync for the life of the
    # session via a background watcher that talks over this connection's SSH
    # ControlMaster socket (no re-auth, ~instant).
    set -l ctl ~/.ssh/devbox.ctl
    set -l mode (~/.config/tmux/github-theme.sh mode)

    fish -c "__dev_theme_watch $ctl $mode" &
    disown

    # ControlPersist=no: the master (this ssh) closes with the session, which
    # removes the socket and lets the watcher exit on its own.
    ssh -t -o ControlMaster=auto -o ControlPath=$ctl -o ControlPersist=no devbox \
        "~/.config/tmux/github-theme.sh apply $mode 2>/dev/null; tmux attach 2>/dev/null || tmux new"
end
