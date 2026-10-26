#include "harness_start.bash"

# A tab between the words of a Configfile line is white space like any
# other, so "TESTDEPS<tab>+=<tab>path" is the same line as the one with
# spaces.  Split on single spaces as it stood, a "#pconfigure" with tabs
# between its words came out as one word, and the test was refused
# because "TESTDEPS<tab>+=<tab>testexec/tool" is not a command.
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

# Written with printf rather than in a heredoc: a "#" in the first
# column of this file is a directive for this file.
printf '#pconfigure TESTDEPS\t+=\ttestexec/tool\n' > test/app/needs-tool.bash
cat >>test/app/needs-tool.bash <<'EOT'
test -x "$(dirname "$PTEST_BINARY")/../testexec/tool"
EOT

$PTEST_BINARY $PCONFIGURE_ARGS
grep '^check/app/needs-tool.bash:.*testexec/tool' Makefile
make $MAKE_ARGS check/app/needs-tool.bash
test "$(tar -xOf check/app/needs-tool.bash ptest__return)" = 0
