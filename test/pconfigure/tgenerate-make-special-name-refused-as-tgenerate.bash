#include "harness_start.bash"

# A TGENERATE is a GENERATE whose script lives under test/, and the
# file it names lands on the left of a rule in exactly the same way, so
# a '#', a ':' or an '=' in it has to be refused at its line just as a
# GENERATE's is.  The refusal has to say TGENERATE, too: one that said
# GENERATE would send whoever reads it looking for a line that isn't
# in the Configfile.

top="$tempdir"

for name in 'gen#1.h' 'gen:1.h' 'gen=1.h'
do
    dir="$top/$(echo "$name" | tr '#:=' 'hce')"
    mkdir -p "$dir/src" "$dir/test"
    echo 'int main(void) { return 0; }' > "$dir/src/main.c"
    cat > "$dir/test/$name.proc" <<'EOC'
#!/bin/sh
case "$1" in
--deps) ;;
--generate) echo '#define VALUE 0' ;;
esac
EOC
    chmod +x "$dir/test/$name.proc"
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
    grep -qF "error: TGENERATE has a '${name//[^#:=]/}' in it" "$dir.out"
    test ! -e "$dir/Makefile"
done
