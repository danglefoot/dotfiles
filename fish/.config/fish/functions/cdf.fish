# cdf - find a directory below cwd and cd into it
# With one match (or after picking in fzf), changes into it.
# Usage: cdf [query]   e.g. cdf src

function cdf --description 'cd into a dir matching query below cwd (fzf picker)'
    set -l dir (fd --type d --hidden --exclude .git | fzf --query="$argv" --select-1 --exit-0)
    test -n "$dir"; and cd $dir
end
