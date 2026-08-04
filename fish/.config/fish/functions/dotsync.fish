function dotsync --description "sync dotfiles + nvim config with remotes"
    set -l dot ~/.dotfiles
    set -l nvim_dir $dot/nvim/.config/nvim

    echo "── nvim ──"
    # Auto-commit local edits; commit manually first if you want a real message
    if test -n "$(git -C $nvim_dir status --porcelain)"
        git -C $nvim_dir add -A
        git -C $nvim_dir commit -m "sync from $(hostname -s)"
    end
    git -C $nvim_dir pull --rebase; and git -C $nvim_dir push
    or begin
        echo "dotsync: nvim sync failed — resolve in $nvim_dir" >&2
        return 1
    end

    echo "── dotfiles ──"
    git -C $dot pull --rebase --autostash
    or begin
        echo "dotsync: dotfiles rebase failed — resolve in $dot" >&2
        return 1
    end
    if not git -C $dot diff --quiet -- nvim/.config/nvim
        git -C $dot add nvim/.config/nvim
        git -C $dot commit -m "Bump nvim submodule"
    end
    git -C $dot push
    echo "── synced ──"
end
