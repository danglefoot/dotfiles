if status is-interactive
    # Commands to run in interactive sessions can go here
end

starship init fish | source
zoxide init fish | source
fzf --fish | source

alias ll="eza -l -g --icons --git"
alias llt="eza -1 --icons --tree --git-ignore"
alias k="kubectl"
alias kns='kubectl config set-context --current --namespace'

# Git aliases
alias g="git"
alias gs="git status"
alias ga="git add"
alias gaa="git add --all"
alias gc="git commit"
alias gcm="git commit -m"
alias gca="git commit --amend"
alias gcan="git commit --amend --no-edit"
alias gp="git push"
alias gpf="git push --force-with-lease"
alias gl="git pull"
alias gf="git fetch"
alias gd="git diff"
alias gds="git diff --staged"
alias gco="git checkout"
alias gcob="git checkout -b"
alias gb="git branch"
alias gba="git branch -a"
alias gbd="git branch -d"
alias glog="git log --oneline --graph --decorate"
alias gloga="git log --oneline --graph --decorate --all"
alias gst="git stash"
alias gstp="git stash pop"
alias gstl="git stash list"
alias gr="git restore"
alias grs="git restore --staged"
alias gsw="git switch"
alias gswc="git switch -c"
alias gm="git merge"
alias grb="git rebase"
alias grbi="git rebase -i"
alias grbc="git rebase --continue"
alias grba="git rebase --abort"
alias gcp="git cherry-pick"
alias gcl="git clone"
alias gsh="git show"
alias gwt="git worktree"

function y
	set tmp (mktemp -t "yazi-cwd.XXXXXX")
	yazi $argv --cwd-file="$tmp"
	if set cwd (command cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
		builtin cd -- "$cwd"
	end
	rm -f -- "$tmp"
end

function mkcd
    mkdir -p $argv[1]
    and cd $argv[1]
end

# pnpm
set -gx PNPM_HOME "/Users/colin/Library/pnpm"
if not string match -q -- $PNPM_HOME $PATH
  set -gx PATH "$PNPM_HOME" $PATH
end
# pnpm end

set -gx XDG_CONFIG_HOME $HOME/.config
set -gx XDG_DATA_HOME $HOME/.local/share
set -gx XDG_STATE_HOME $HOME/.local/state
set -gx XDG_CACHE_HOME $HOME/.cache
set -gx EDITOR (type -p nvim)

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH

set -gx DOTNET_ROOT /usr/local/share/dotnet
fish_add_path $HOME/.dotnet
fish_add_path $DOTNET_ROOT
