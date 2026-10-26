#include "harness_start.bash"

# A TGENERATE names a file just as a GENERATE does, only with its
# script under test/, so a name that ends as a directory has to be
# refused at its line the same way.  The refusal has to say TGENERATE:
# one that said GENERATE would send whoever reads it looking for a line
# that isn't in the Configfile.

top="$tempdir"

i=0
for name in 'gen.h/' 'sub/..' '.'
do
    i=$((i + 1))
    dir="$top/case$i"
    mkdir -p "$dir/src" "$dir/test/sub"
    echo 'int main(void) { return 0; }' > "$dir/src/main.c"
    cat > "$dir/test/gen.h.proc" <<'EOC'
#!/bin/sh
case "$1" in
--deps) ;;
--generate) echo '#define VALUE 0' ;;
esac
EOC
    chmod +x "$dir/test/gen.h.proc"
    cat > "$dir/Configfile" <<EOC
LANGUAGES   += c
TGENERATE   += $name
BINARIES    += main
SOURCES     += main.c
EOC

    if (cd "$dir" && $PTEST_BINARY $PCONFIGURE_ARGS) > "$dir.out" 2>&1
    then
        cat "$dir.out"
        echo "TGENERATE += $name was accepted" >&2
        exit 1
    fi
    cat "$dir.out"
    grep -q "Configfile:2" "$dir.out"
    grep -qF "error: TGENERATE names a directory rather than a file: '$name'" "$dir.out"
    grep -qF "TGENERATE += gen.h" "$dir.out"
    test ! -e "$dir/Makefile"
done
