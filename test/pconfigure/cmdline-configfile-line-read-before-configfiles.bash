#include "harness_start.bash"

# A Configfile line given on the command line comes before any file is
# read, so a tree whose Configfile names targets but no language can be
# configured by saying the language at the shell -- and the line is
# recorded, so a reconfigure keeps it.
mkdir -p src
echo 'int main(void) { return 0; }' > src/hello.c
cat >Configfile <<'EOF'
BINARIES += hello
SOURCES  += hello.c
EOF

# On its own the Configfile can't be configured: nothing says what
# language hello.c is.
if $PTEST_BINARY > out 2>&1
then
    cat out
    exit 1
fi
rm -f Makefile

$PTEST_BINARY 'LANGUAGES += c'
grep -q "^PCONFIGURE_ARGS ?= 'LANGUAGES += c'\$" Makefile
make $MAKE_ARGS
test -x bin/hello

# make reconfigure runs it the same way: the regenerated Makefile still
# knows how to build hello, and still records the line for the next
# rerun.
make $MAKE_ARGS reconfigure
grep -q '^bin/hello:' Makefile
grep -q "^PCONFIGURE_ARGS ?= 'LANGUAGES += c'\$" Makefile
rm -f bin/hello
make $MAKE_ARGS
test -x bin/hello
