#include "harness_start.bash"

# A PHONY is nothing but a name on a rule line, which makes it the
# purest case of a target name: a '#' in it comments out the rest of
# the rule and a ':' cuts it in two, and make stops reading the
# Makefile with an error about a separator or a '%' that points at a
# Makefile line rather than at the PHONY that wrote it.  BINARIES with
# the same characters is refused where it was written.

top="$tempdir"

for name in 'do#it' 'do:it' 'do=it'
do
    dir="$top/$(echo "$name" | tr '#:=' 'hce')"
    mkdir -p "$dir/src"
    echo 'int main(void) { return 0; }' > "$dir/src/main.c"
    cat > "$dir/Configfile" <<EOC
LANGUAGES   += c
BINARIES    += main
SOURCES     += main.c
PHONY       += $name
EOC

    if (cd "$dir" && $PTEST_BINARY $PCONFIGURE_ARGS) > "$dir.out" 2>&1
    then
        cat "$dir.out"
        echo "PHONY += $name was accepted" >&2
        exit 1
    fi
    cat "$dir.out"
    grep -q "Configfile:4" "$dir.out"
    grep -qF "error: PHONY has a '${name//[^#:=]/}' in it" "$dir.out"
    test ! -e "$dir/Makefile"
done
