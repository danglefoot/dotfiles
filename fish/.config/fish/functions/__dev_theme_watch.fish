function __dev_theme_watch --description "dev helper: push macOS appearance to devbox while its ssh master socket lives"
    # usage: __dev_theme_watch <control-socket> <initial-mode>
    set -l ctl $argv[1]
    set -l have $argv[2]

    # Wait for the master socket (auth may take a moment); give up if ssh never
    # connected.
    for _ in (seq 60)
        test -S $ctl; and break
        sleep 1
    end

    while test -S $ctl
        sleep 3
        set -l want (~/.config/tmux/github-theme.sh mode)
        test "$want" = "$have"; and continue
        # Reuses the live connection; re-themes remote tmux and rewrites the mode
        # file that remote nvim polls.
        ssh -o ControlMaster=no -o ControlPath=$ctl devbox \
            "~/.config/tmux/github-theme.sh apply $want" >/dev/null 2>&1
        and set have $want
    end
end
