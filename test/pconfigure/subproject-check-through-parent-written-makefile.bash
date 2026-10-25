#include "harness_start.bash"

# The Makefile the top writes for a subproject can be run from inside
# that subproject, and "check" through it runs the subproject's own
# tests against its own binary: the results land in the subproject's
# check directory, the same place a check from the top puts them.
mkdir -p sub/src sub/test/tool

cat >Configfile <<'EOF'
SUBPROJECTS += sub
EOF

cat >sub/Configfile <<'EOF'
LANGUAGES += c
LANGUAGES += bash
BINARIES  += tool
SOURCES   += tool.c
TESTSRC   += runs.bash
EOF

echo 'int main(void) { return 7; }' > sub/src/tool.c

cat >sub/test/tool/runs.bash <<'EOF'
$PTEST_BINARY
test "$?" = "7"
EOF

$PTEST_BINARY $PCONFIGURE_ARGS

(cd sub && make $MAKE_ARGS -f obj/Makefile.sub check)
test -x sub/bin/tool
test "$(tar -xOf sub/check/tool/runs.bash ptest__return)" = "0"
test ! -e check

# From the top the same result is already there and up to date.
make $MAKE_ARGS check > top.out 2>&1
cat top.out
if grep -q "^CHECK	" top.out
then
    exit 1
fi

exit 0
