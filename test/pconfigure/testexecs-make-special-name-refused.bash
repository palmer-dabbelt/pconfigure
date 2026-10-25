#include "harness_start.bash"

# A TESTEXECS names a program the Makefile builds, exactly as a
# BINARIES does: its name goes onto rule lines and into the recipes
# that link it.  A '#' or a ':' in it makes a Makefile that make
# can't read ("missing separator", "target pattern contains no '%'"),
# which names neither the character nor the Configfile line.  The
# BINARIES spelling of the same mistake is refused at the line, and so
# should this one be.

top="$tempdir"

for name in 'probe#1' 'probe:1'
do
    dir="$top/$(echo "$name" | tr '#:' 'hc')"
    mkdir -p "$dir/src"
    echo 'int main(void) { return 0; }' > "$dir/src/main.c"
    cat > "$dir/Configfile" <<EOC
LANGUAGES   += c
TESTEXECS   += $name
SOURCES     += main.c
EOC

    if (cd "$dir" && $PTEST_BINARY $PCONFIGURE_ARGS) > "$dir.out" 2>&1
    then
        cat "$dir.out"
        echo "TESTEXECS += $name was accepted" >&2
        exit 1
    fi
    cat "$dir.out"
    grep -q "Configfile:2" "$dir.out"
    grep -qF "error: TESTEXECS has a '${name//[^#:=]/}' in it" "$dir.out"
    test ! -e "$dir/Makefile"
done
