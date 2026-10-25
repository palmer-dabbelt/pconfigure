#include "harness_start.bash"

# A GENERATE names a file the Makefile builds, and already refuses a
# '$', a quote and a ';' at its line.  A '#', a ':' or an '=' get no
# further than that in a BINARIES, but here they are let through, and
# what comes out is a Makefile make can't read: the rule for the
# generated file is a comment, a pattern rule or an assignment, and
# the error names a Makefile line rather than the GENERATE.

top="$tempdir"

for name in 'gen#1.h' 'gen:1.h' 'gen=1.h'
do
    dir="$top/$(echo "$name" | tr '#:=' 'hce')"
    mkdir -p "$dir/src"
    echo 'int main(void) { return 0; }' > "$dir/src/main.c"
    cat > "$dir/src/$name.proc" <<'EOC'
#!/bin/sh
case "$1" in
--deps) ;;
--generate) echo '#define VALUE 0' ;;
esac
EOC
    chmod +x "$dir/src/$name.proc"
    cat > "$dir/Configfile" <<EOC
LANGUAGES   += c
GENERATE    += $name
BINARIES    += main
SOURCES     += main.c
EOC

    if (cd "$dir" && $PTEST_BINARY $PCONFIGURE_ARGS) > "$dir.out" 2>&1
    then
        cat "$dir.out"
        echo "GENERATE += $name was accepted" >&2
        exit 1
    fi
    cat "$dir.out"
    grep -q "Configfile:2" "$dir.out"
    grep -qF "error: GENERATE has a '${name//[^#:=]/}' in it" "$dir.out"
    test ! -e "$dir/Makefile"
done
