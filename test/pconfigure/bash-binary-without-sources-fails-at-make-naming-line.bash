#include "harness_start.bash"

# A BASH binary with no SOURCES under it -- the SOURCES line
# forgotten, or written against the wrong target -- gets the warning
# every target with nothing in it gets, naming the line, which STRICT
# can turn into an error.  The BASH language then reached for the
# first of its sources to hand pbashc without asking whether there was
# one, and pconfigure died of a segmentation fault right after the
# warning that said this was only worth a warning.
#
# A warning means the Makefile still comes out, with the target beside
# it that did have a source building as before.  There is nothing to
# make "other" from, though, so its rule fails when make gets there
# and says which line it was, rather than leaving a script behind.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash

BINARIES  += other
EOF

cat >src/tool.bash <<'EOF'
echo tool
EOF

set +e
$PTEST_BINARY $PCONFIGURE_ARGS 2>stderr
status="$?"
set -e
cat stderr

test "$status" == 0
grep -q "Configfile:6 'BINARIES += other'" stderr
grep -q "has nothing to build" stderr

make $MAKE_ARGS bin/tool
test "$(bash bin/tool)" == "tool"

if make $MAKE_ARGS >make.out 2>&1
then
    cat make.out
    exit 1
fi
cat make.out
grep -q "Configfile:6: other has no SOURCES to be made from" make.out
test ! -e bin/other
