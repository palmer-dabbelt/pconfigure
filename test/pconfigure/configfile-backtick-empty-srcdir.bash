#include "harness_start.bash"

# A SRCDIR is pasted in front of every source below it, so an empty one
# turns "main.c" into "/main.c": a file read from the root of the
# filesystem, and an object directory named after it.  "SRCDIR =" on
# its own is refused for that reason; a backtick that printed nothing
# leaves the line saying the same thing and must not get further.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfile <<'EOF'
LANGUAGES   += c

SRCDIR       = `true`
BINARIES    += main
SOURCES     += main.c
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    grep -n "main.c" Makefile || true
    echo "SRCDIR set to nothing by a backtick was accepted" >&2
    exit 1
fi
cat out
grep -q "Configfile:3" out
grep -q "printed nothing" out
test ! -e Makefile
