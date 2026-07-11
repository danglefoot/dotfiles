function bat --description 'bat, with the theme following the tmux/system appearance'
    # bat's own light/dark auto-detection queries the terminal background, which
    # tmux blocks — so it can't tell light from dark inside tmux. Instead reuse
    # the reliable signal the status-bar watcher already maintains:
    # @github-theme-mode (kept current via System Events). Fall back to a live
    # query when running outside tmux.
    set -l mode (tmux show-option -gqv @github-theme-mode 2>/dev/null)
    if test -z "$mode"
        if test (osascript -e 'tell application "System Events" to tell appearance preferences to return dark mode' 2>/dev/null) = true
            set mode dark
        else
            set mode light
        end
    end

    if test "$mode" = dark
        command bat --theme="Visual Studio Dark+" $argv
    else
        command bat --theme="GitHub" $argv
    end
end
