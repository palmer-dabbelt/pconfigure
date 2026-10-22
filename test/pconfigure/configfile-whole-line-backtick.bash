#include "harness_start.bash"

# A backtick can produce a whole line, command and all, and a line that
# was nothing but a command which printed nothing is no line at all
# rather than a malformed one.  This is how a Configfile includes a
# line only on some machines: the command decides whether to print it.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c
echo 'int main(void) { return 1; }' > src/never.c

cat >Configfile <<'EOF'
LANGUAGES   += c

`echo BINARIES += main`
`true`
`if false; then echo SOURCES += never.c; fi`
SOURCES     += main.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
if grep -q "never.c" Makefile
then
    exit 1
fi
make $MAKE_ARGS
./bin/main
