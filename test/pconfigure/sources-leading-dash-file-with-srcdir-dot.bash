#include "harness_start.bash"

# A source file whose name starts with a '-', in a project with its
# sources at the top.  The path a compiler is handed is the source
# directory and the name joined up, which with "SRCDIR = ." is
# "./-f.c" -- a file, not an option -- and so it compiles, links and
# can be edited like any other.  The archive member named after it is
# a file too.
echo 'int f(void) { return 0; }' > ./-f.c
echo 'int f(void); int main(void) { return f(); }' > main.c

cat >Configfile <<EOF
LANGUAGES += c
SRCDIR     = .

LIBRARIES += libf.a
SOURCES   += -f.c

BINARIES  += main
DEPLIBS   += f
SOURCES   += main.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
./bin/main
test "$(ar t lib/libf.a | wc -l | tr -d ' ')" = 1
nm lib/libf.a | grep -q ' T f$'

sleep 1
echo 'int f(void) { return 4; }' > ./-f.c
make $MAKE_ARGS
set +e
./bin/main
status=$?
set -e
test "$status" = 4
