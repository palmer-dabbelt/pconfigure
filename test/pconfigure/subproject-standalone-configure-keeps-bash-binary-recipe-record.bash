#include "harness_start.bash"

# The same per-run record as for a test's script, for a script that is
# a program instead: a BASH BINARIES in a subproject must not be rebuilt
# by one run's make because the other run was configured, since
# neither its source nor its options changed.
mkdir -p sub/src

cat >Configfile <<'EOF'
SUBPROJECTS += sub
EOF

cat >sub/Configfile <<'EOF'
LANGUAGES += bash
BINARIES  += hello
SOURCES   += hello.bash
EOF

echo 'echo hello' > sub/src/hello.bash

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(sub/bin/hello)" = "hello"

(cd sub && $PTEST_BINARY $PCONFIGURE_ARGS)

make $MAKE_ARGS > top.out 2>&1
cat top.out
if grep -q "^BASH	" top.out
then
    exit 1
fi

(cd sub && make $MAKE_ARGS)
$PTEST_BINARY $PCONFIGURE_ARGS
(cd sub && make $MAKE_ARGS) > sub.out 2>&1
cat sub.out
if grep -q "^BASH	" sub.out
then
    exit 1
fi
test "$(sub/bin/hello)" = "hello"

exit 0
