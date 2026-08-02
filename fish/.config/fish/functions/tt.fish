function tt --description "Switch tmux GitHub theme: tt light|dark"
    if test (count $argv) -ne 1; or not contains -- $argv[1] light dark
        echo "usage: tt light|dark" >&2
        return 64
    end
    ~/.config/tmux/github-theme.sh apply $argv[1]
end
