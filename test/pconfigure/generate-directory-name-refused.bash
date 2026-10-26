#include "harness_start.bash"

# What a GENERATE names is a file: the one its script writes, and with
# ".proc" on the end the script itself.  A name that ends as a
# directory -- a trailing '/', or a last component of "." or ".." --
# used to be normalized into "gen.h/" or ".", and pconfigure then went
# looking for "src/gen.h/.proc" or "src/..proc" and told the reader to
# write the script there, while the src/gen.h.proc that really was
# there went unmentioned.  Each spelling has to be refused at its line,
# saying what to write instead, before any Makefile is written.

top="$tempdir"

i=0
for name in 'gen.h/' 'sub/gen.h/' 'sub/..' 'sub/.' '.' './'
do
    i=$((i + 1))
    dir="$top/case$i"
    mkdir -p "$dir/src/sub"
    cat > "$dir/src/gen.h.proc" <<'EOC'
#!/bin/sh
case "$1" in
--deps) ;;
--generate) echo '#define VALUE 0' ;;
esac
EOC
    chmod +x "$dir/src/gen.h.proc"
    cat > "$dir/Configfile" <<EOC
LANGUAGES   += c
GENERATE    += $name
EOC

    if (cd "$dir" && $PTEST_BINARY $PCONFIGURE_ARGS) > "$dir.out" 2>&1
    then
        cat "$dir.out"
        echo "GENERATE += $name was accepted" >&2
        exit 1
    fi
    cat "$dir.out"
    grep -q "Configfile:2" "$dir.out"
    grep -qF "error: GENERATE names a directory rather than a file: '$name'" "$dir.out"
    grep -qF "GENERATE += gen.h" "$dir.out"
    if grep -qE '/\.proc|\.\.proc' "$dir.out"
    then
        exit 1
    fi
    test ! -e "$dir/Makefile"
done
