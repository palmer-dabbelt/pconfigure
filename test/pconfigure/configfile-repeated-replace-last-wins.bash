#include "harness_start.bash"

# A command written with '=' replaces whatever it was set to before,
# which is what makes Configfiles/local useful: it is read first, so
# the project's own Configfile has the last word on anything it sets,
# and the same command written twice in one file means the second
# value.  LIBDIR and PREFIX are the two whose answer can be seen in
# the generated Makefile without building anything.
mkdir -p src
echo 'int foo(void) { return 0; }' > src/foo.c

cat >Configfile <<'EOF'
LANGUAGES   += c

PREFIX       = /opt/first
PREFIX       = /opt/second

LIBDIR       = firstlib
LIBDIR       = secondlib
LIBRARIES   += libfoo.so
SOURCES     += foo.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
grep -q "^secondlib/libfoo.so:" Makefile
if grep -q "firstlib" Makefile
then
    exit 1
fi
grep -q "/opt/second" Makefile
if grep -q "/opt/first" Makefile
then
    exit 1
fi

make $MAKE_ARGS
test -f secondlib/libfoo.so
test ! -e firstlib
