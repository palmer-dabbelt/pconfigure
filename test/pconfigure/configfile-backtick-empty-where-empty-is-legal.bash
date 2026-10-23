#include "harness_start.bash"

# A command in backticks that printed nothing for the value of an '='
# is refused, because "LIBDIR =" is refused however it was arrived at.
# That refusal must not reach any further than the lines that are
# refused when typed: the places where an empty answer is a legal one
# have to keep working.
#
# A line that is nothing but a command which printed nothing has no
# line left in it, so it is skipped rather than refused.  And
# "CROSS_COMPILE =" with nothing after it is how a target takes back a
# cross toolchain it inherited, so one that a backtick emptied is that
# same request, not a mistake.  (An append of nothing is the third, and
# has a test of its own.)
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfile <<'EOF2'
LANGUAGES     += c

`true`
`echo "   "`
CROSS_COMPILE  = `true`
BINARIES      += main
SOURCES       += main.c
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1 || {
    cat out
    echo "an empty answer where an empty answer is legal was refused" >&2
    exit 1
}
cat out

make $MAKE_ARGS
./bin/main
