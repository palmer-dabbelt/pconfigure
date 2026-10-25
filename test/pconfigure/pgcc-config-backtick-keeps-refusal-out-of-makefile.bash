#include "harness_start.bash"

# The way pgcc-config is meant to be used, end to end: a flag that
# only some compilers understand, guarded by the compiler's version.
# With a compiler newer than GCC 4 pgcc-config can't make the
# comparison and gives up.  Whatever it prints on stdout is what the
# backtick hands pconfigure as compile options, so its reason for
# giving up has to arrive on stderr: on stdout, "OSX doesn't have sort
# -V, ..." becomes seven words of the compile line, and the compiler
# complains about input files called "OSX" and "doesn't".
#
# A guard that can't decide should leave the flag out (or stop
# configuring), not put its own explanation on the compile line.
export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p fakebin src
cat >fakebin/modern-cc <<'EOF'
#!/bin/bash
if [[ "$1" == "-dumpversion" ]]
then
    echo 13
    exit 0
fi
exec cc "$@"
EOF
chmod +x fakebin/modern-cc
export PATH="$(pwd)/fakebin:$PATH"

cat >Configfile <<EOF
LANGUAGES   += c
COMPILEOPTS += \`pgcc-config modern-cc 4.5 gt -Wall\`

BINARIES    += test
SOURCES     += test.c
EOF

cat >src/test.c <<EOF
int main(void) { return 0; }
EOF

set +e
$PTEST_BINARY $PCONFIGURE_ARGS 2>stderr
status="$?"
set -e
cat stderr

# The reason reaches the person running pconfigure either way.
grep -q "pgcc-config" stderr

if [[ "$status" != "0" ]]
then
    grep -q "Configfile:2" stderr
    exit 0
fi

cat Makefile
if grep -q "OSX\|sort -V\|only support\|can be compared" Makefile
then
    exit 1
fi

make $MAKE_ARGS
