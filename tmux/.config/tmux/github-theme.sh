#!/usr/bin/env bash
# GitHub theme for tmux.
#
# Paints the status bar with GitHub's Primer palette and follows the macOS
# system appearance: GitHub Light in light mode, GitHub Dark in dark mode.
#
#   github-theme.sh [apply] [light|dark]   # apply (no mode arg = follow system)
#   github-theme.sh watch                  # re-apply only if appearance changed
#
# Switching is driven by an invisible #() call embedded in status-right that
# tmux re-evaluates every `status-interval` seconds. Detection uses
# `defaults read AppleInterfaceStyle` (reliable inside tmux), NOT a terminal
# background query.

set -euo pipefail

detect_mode() {
  # Use System Events for the LIVE appearance. `defaults read AppleInterfaceStyle`
  # is unreliable here: its .GlobalPreferences cache often returns a stale value
  # after a light<->dark toggle, so the bar would never switch.
  local dark
  dark=$(osascript -e 'tell application "System Events" to tell appearance preferences to return dark mode' 2>/dev/null)
  if [[ "$dark" == "true" ]]; then
    echo dark
  else
    echo light
  fi
}

apply() {
  local mode="$1"

  # ---- GitHub Primer palettes ----
  local bar surface border fg muted accent accent_fg red red_fg canvas
  if [[ "$mode" == "dark" ]]; then
    bar="#30363d"       # border.default -> clearly visible bar (not near-black)
    surface="#21262d"   # border.muted   -> recessed host chip
    border="#768390"    # window dividers
    fg="#f0f3f6"
    muted="#c9d1d9"     # inactive windows / date (lighter, more readable)
    accent="#58a6ff"
    accent_fg="#0d1117"
    red="#f85149"
    red_fg="#0d1117"
    canvas="#22272e"    # Ghostty "GitHub Dark Dimmed" background -> pane bg
  else
    bar="#eaeef2"       # light bar background
    surface="#f6f8fa"   # host chip / messages
    border="#8c959f"    # window dividers
    fg="#1f2328"        # near-black text
    muted="#57606a"     # inactive windows / date
    accent="#0969da"
    accent_fg="#ffffff"
    red="#cf222e"
    red_fg="#ffffff"
    canvas="#ffffff"    # Ghostty "GitHub Light High Contrast" background -> pane bg
  fi

  # Absolute path so the embedded watcher works regardless of cwd / tilde.
  local self="${HOME}/.config/tmux/github-theme.sh"

  # Heavy vertical-bar divider (U+2503), built from raw UTF-8 bytes via printf so
  # it survives editing. This is the box-drawing "heavy" weight — one step thicker
  # than the light │ (U+2502). No powerline/breadcrumb chevrons.
  local pipe
  pipe=$(printf '\342\224\203')  # U+2503  ┃

  # Full-width line for the second status line: a bottom border that visually
  # separates the bar from the panes. Uses U+1FB82 (🮂 upper one-quarter block),
  # which fills the TOP quarter of its cell so — on a canvas-coloured row directly
  # under the bar — it hugs the bar's bottom edge and grows downward. (U+2594, the
  # upper one-eighth block, was half this thickness; block glyphs quantise to
  # eighths of a cell, so a quarter is the next step up.) Padded wide; tmux
  # truncates to terminal width.
  local rule
  rule=$(printf '\360\237\256\202%.0s' {1..500})  # U+1FB82  🮂 ×500

  # Date/time shown on the right, e.g. "Fri 10 Jul  14:23:45". Its fields are all
  # fixed-width, so the right-hand layout never shifts as the seconds tick.
  local date='%a %d %b  %H:%M:%S'

  tmux set-option -g status on
  tmux set-option -g status-justify left
  tmux set-option -g status-left-length 80
  tmux set-option -g status-right-length 80
  tmux set-option -g status-left-style none
  tmux set-option -g status-right-style none

  # Base status bar — one flat tone across the whole bar.
  tmux set-option -g status-style "bg=${bar},fg=${muted}"

  # Second status line = a hairline bottom border under the bar. status-format[0]
  # stays default (the real bar); status-format[1] is just the rule. With
  # status-position top, line 0 is topmost and line 1 sits directly below it,
  # between the bar and the panes. Unset first so a re-apply starts from tmux's
  # default rows rather than whatever we set last time.
  tmux set-option -gu status-format
  tmux set-option -g status 2
  # bg=${canvas} (not "default", which tmux resolves to status-style's bar
  # colour) paints this row in the terminal/pane background, so the hairline
  # sits flush on the panes below and reads as the bar's bottom edge rather than
  # riding on a strip of bar-coloured gray.
  tmux set-option -g status-format[1] "#[bg=${canvas},fg=${border}]${rule}"

  # Pipe divider between windows.
  tmux set-window-option -g window-status-separator "#[bg=${bar},fg=${border}]${pipe}"

  # Left: session name on a red block.
  tmux set-option -g status-left \
    "#[bg=${red},fg=${red_fg},bold] #S #[bg=${bar},fg=${muted}] "

  # Right: preserve tmux-continuum's autosave hook (it prepends its own #() to
  # status-right at load), then the invisible appearance watcher, then
  #  date  time | host .
  local keep
  keep="$(tmux show-option -gqv status-right 2>/dev/null \
    | grep -oE '#\([^)]*continuum_save\.sh\)' || true)"
  tmux set-option -g status-right \
    "${keep}#(${self} watch)#[bg=${bar},fg=${muted}] ${date} #[fg=${border}]${pipe}#[fg=${fg}] #h "

  # Inactive = flat muted text on the bar; active = a blue block with contrasting
  # text (mirrors the red session block).
  tmux set-window-option -g window-status-format \
    "#[bg=${bar},fg=${muted}] #I #W#{?window_zoomed_flag, *Z,} "
  tmux set-window-option -g window-status-current-format \
    "#[bg=${accent},fg=${accent_fg},bold] #I #W#{?window_zoomed_flag, *Z,} "
  tmux set-window-option -g window-status-activity-style "bg=${bar},fg=${fg}"
  tmux set-window-option -g window-status-bell-style "bg=${red},fg=${red_fg}"

  # Panes.
  tmux set-option -g pane-border-style "fg=${border}"
  tmux set-option -g pane-active-border-style "fg=${accent}"
  tmux set-option -g display-panes-colour "${border}"
  tmux set-option -g display-panes-active-colour "${accent}"

  # Messages / command prompt.
  tmux set-option -g message-style "bg=${surface},fg=${fg}"
  tmux set-option -g message-command-style "bg=${surface},fg=${fg}"

  # Copy-mode selection + clock.
  tmux set-window-option -g mode-style "bg=${accent},fg=${accent_fg}"
  tmux set-window-option -g clock-mode-colour "${accent}"

  # Record what we applied so `watch` can detect changes.
  tmux set-option -g @github-theme-mode "${mode}"

  # Changing style options at runtime (from the #() watcher) updates the options
  # but does NOT repaint the bar on its own, so force a status-line redraw.
  # Harmless (and a no-op) when no client is attached.
  tmux refresh-client -S 2>/dev/null || true
}

case "${1:-apply}" in
apply)
  # `apply [light|dark]` forces a mode; with no arg, follow the system.
  apply "${2:-$(detect_mode)}"
  ;;
watch)
  # Invisible side-effect call from status-right: re-theme only when the macOS
  # appearance has changed since the last apply. Emits nothing.
  #
  # status-interval is 1s (so the clock's seconds tick), but polling the
  # appearance that often would spawn osascript every second. Throttle to ~5s
  # using an mtime marker; the seconds keep ticking, the poll stays cheap.
  stamp="${TMPDIR:-/tmp}/.tmux-github-theme-poll"
  if [[ -f "$stamp" ]]; then
    now=$(date +%s)
    last=$(date -r "$stamp" +%s 2>/dev/null || echo 0)
    (( now - last < 5 )) && exit 0
  fi
  : > "$stamp"
  want="$(detect_mode)"
  have="$(tmux show-option -gqv @github-theme-mode)"
  [[ "$want" != "$have" ]] && apply "$want"
  ;;
*)
  echo "usage: github-theme.sh [apply [light|dark]] | watch" >&2
  exit 64
  ;;
esac
