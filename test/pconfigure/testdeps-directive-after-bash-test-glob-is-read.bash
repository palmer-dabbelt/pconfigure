#include "harness_start.bash"

# A bash test is read for its "#pconfigure" lines the way pbashc reads
# it for its includes: as a script, line by line.  The "/" and "*" at
# the end of a glob open no comment in a shell, but read as C they
# open one that nothing closes, and a directive under the glob would
# be blanked with everything else after it.  The test would then run
# before the program it said it needed was built.
mkdir -p src test/main

cat >Configfile <<'EOF'
LANGUAGES += c
LANGUAGES += bash

TESTEXECS += tool
SOURCES   += tool.c

BINARIES  += main
SOURCES   += main.c
TESTSRC   += uses-tool.bash
EOF

echo 'int main(void) { return 0; }' > src/tool.c
echo 'int main(void) { return 0; }' > src/main.c

# Written with echo rather than a heredoc, since a '#' in the first
# column of this file is read by the pconfigure that builds it.
{
    echo 'ls "$PTEST_BINARY"/* >/dev/null 2>&1 || true'
    echo '#pconfigure TESTDEPS += testexec/tool'
    echo 'test -x "$(dirname "$PTEST_BINARY")/../testexec/tool"'
} > test/main/uses-tool.bash

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

grep -q "^check/main/uses-tool.bash:.* testexec/tool" Makefile

make $MAKE_ARGS check
test "$(tar -xOf check/main/uses-tool.bash ptest__return)" = 0
