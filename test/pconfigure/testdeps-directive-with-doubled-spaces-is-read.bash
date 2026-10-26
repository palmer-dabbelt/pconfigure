#include "harness_start.bash"

# A Configfile line is tidied to single spaces before it is read, so
# lining the operators up with extra spaces is harmless there, and a
# "#pconfigure" directive is the same kind of line written in a test.
# Split on single spaces as it stood, "TESTDEPS  +=  testexec/tool"
# came out with empty words in it: the operator was read as '', and
# the refusal suggested writing "TESTDEPS += +=  testexec/tool".
mkdir -p src test/app
cat >Configfile <<'EOT'
LANGUAGES += c
LANGUAGES += bash

TESTEXECS += tool
SOURCES   += tool.c

BINARIES  += app
SOURCES   += app.c
TESTSRC   += needs-tool.bash
EOT
echo 'int main(void) { return 0; }' > src/tool.c
echo 'int main(void) { return 0; }' > src/app.c

# Written with echo rather than in a heredoc: a "#" in the first
# column of this file is a directive for this file.
echo '#pconfigure TESTDEPS  +=  testexec/tool' > test/app/needs-tool.bash
cat >>test/app/needs-tool.bash <<'EOT'
test -x "$(dirname "$PTEST_BINARY")/../testexec/tool"
EOT

$PTEST_BINARY $PCONFIGURE_ARGS
grep '^check/app/needs-tool.bash:.*testexec/tool' Makefile
make $MAKE_ARGS check/app/needs-tool.bash
test "$(tar -xOf check/app/needs-tool.bash ptest__return)" = 0
