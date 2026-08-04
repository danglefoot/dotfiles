function dev --description "ssh to devbox and attach tmux"
    ssh -t devbox 'tmux attach 2>/dev/null || tmux new'
end
