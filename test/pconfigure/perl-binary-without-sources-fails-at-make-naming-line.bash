#include "harness_start.bash"

# A Perl script is built by the same code as a BASH one, so a Perl
# binary with no SOURCES died the same way: the warning that it has
# nothing to build, and then a segmentation fault as pconfigure
# reached for a first source that wasn't there.  It is still only a
# warning, so the Makefile comes out, and the rule for the script fails
# when make gets to it, naming the line.
mkdir -p src

cat >Configfile <<EOF
LANGUAGES += perl

BINARIES  += tool.pl
EOF

set +e
$PTEST_BINARY $PCONFIGURE_ARGS 2>stderr
status="$?"
set -e
cat stderr

test "$status" == 0
grep -q "Configfile:3 'BINARIES += tool.pl'" stderr
grep -q "has nothing to build" stderr

if make $MAKE_ARGS >make.out 2>&1
then
    cat make.out
    exit 1
fi
cat make.out
grep -q "Configfile:3: tool.pl has no SOURCES to be made from" make.out
test ! -e bin/tool.pl
