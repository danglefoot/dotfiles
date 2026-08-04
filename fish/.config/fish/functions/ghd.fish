function ghd --description "gh dash, palette follows macOS appearance"
    if defaults read -g AppleInterfaceStyle 2>/dev/null | string match -q Dark
        gh dash $argv
    else
        # Derive the light config from config.yml by swapping the dark
        # palette (GitHub Dark Dimmed) for GitHub Light High Contrast.
        set -l light ~/.config/gh-dash/config-light.yml
        sed -e 's/#adbac7/#0e1116/' \
            -e 's/#539bf5/#0349b4/' \
            -e 's/#22272e/#ffffff/' \
            -e 's/#768390/#59636e/' \
            -e 's/#c69026/#744500/' \
            -e 's/#57ab5a/#055d20/' \
            -e 's/#2d333b/#e6eaef/g' \
            -e 's/#444c56/#c8d1da/' \
            -e 's/#373e47/#dde3ea/' \
            ~/.config/gh-dash/config.yml >$light
        gh dash --config $light $argv
    end
end
