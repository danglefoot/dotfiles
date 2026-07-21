# Loads before every other conf.d file and before config.fish, so tool-init
# lines (fnm here, starship/zoxide/fzf in config.fish) find their binaries.
# macOS gets these on PATH via Homebrew pre-startup; Linux needs it explicit.
for dir in $HOME/.local/bin $HOME/.local/share/fnm
    test -d $dir; and fish_add_path $dir
end
