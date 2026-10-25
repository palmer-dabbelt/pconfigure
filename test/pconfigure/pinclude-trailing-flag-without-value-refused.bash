#include "harness_start.bash"
#pconfigure TESTDEPS += bin/pinclude

# Now that a bare "-I" or "-D" takes the next word as what it carries,
# one at the very end of the command line has nothing to take.  That
# is a command line cut short, and listing the file as though the flag
# had not been there would hide it, so pinclude refuses and says how
# the flag is spelled.

pinclude="$(dirname "$PTEST_BINARY")/pinclude"

cat >main.c <<'EOF2'
int main(void) { return 0; }
EOF2

for flag in -I -D; do
    if "$pinclude" main.c "$flag" 2>stderr; then
        echo "pinclude took a trailing '$flag'"
        exit 1
    fi
    grep -qF "'$flag' needs something after it" stderr
done
