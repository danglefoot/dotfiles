function degz --description 'Decode a hex-encoded gzip blob to text (auto-handles UTF-16)'
    # Accepts the hex as an argument or on stdin, with or without a leading 0x
    # and ignoring any whitespace. Decompresses, then transcodes UTF-16 -> UTF-8
    # when the output contains NUL bytes (so SQL Server dumps print cleanly).
    set -l hex
    if set -q argv[1]
        set hex "$argv"
    else
        set hex (cat)
    end

    set -l tmp (mktemp)
    string replace -ra '\s|^0x' '' -- "$hex" | xxd -r -p | gunzip >$tmp

    if grep -qU (printf '\x00') $tmp
        iconv -f UTF-16LE -t UTF-8 $tmp
    else
        cat $tmp
    end
    rm -f $tmp
end
