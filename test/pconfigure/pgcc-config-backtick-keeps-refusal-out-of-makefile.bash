#include "harness_start.bash"

# The way pgcc-config is meant to be used, end to end: a flag that
# only some compilers understand, guarded by the compiler's version.
# With a compiler whose -dumpversion isn't a plain <major>.<minor>,
# like the "13-win32" of a Debian MinGW cross GCC, pgcc-config can't
# make the comparison and gives up.  Whatever it prints on stdout is
# what the backtick hands pconfigure as compile options, so its reason
# for giving up has to arrive on stderr: on stdout, the explanation
# becomes a dozen words of the compile line, and the compiler complains
# about input files named after each of them.
#
# A guard that can't decide should leave the flag out (or stop
# configuring), not put its own explanation on the compile line.
export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p fakebin src
cat >fakebin/mingw-cc <<'EOF'
#!/bin/bash
if [[ "$1" == "-dumpversion" ]]
then
    echo 13-win32
    exit 0
fi
exec cc "$@"
EOF
chmod +x fakebin/mingw-cc
export PATH="$(pwd)/fakebin:$PATH"

cat >Configfile <<EOF
LANGUAGES   += c
COMPILEOPTS += \`pgcc-config mingw-cc 4.5 gt -Wall\`

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
if grep -q "dumpversion\|win32\|can be compared" Makefile
then
    exit 1
fi

make $MAKE_ARGS
