#include "harness_start.bash"

# The C half of a "#pconfigure" written with its words spaced out.  A
# C test carries its TESTDEPS on the same kind of line a script does
# and is read by the same code, so "TESTDEPS  +=  testexec/tool" has to
# be tidied the way a Configfile line is here too, rather than refused
# as a TESTDEPS given the operator ''.
mkdir -p src test/app
cat >Configfile <<'EOT'
LANGUAGES += c

TESTEXECS += tool
SOURCES   += tool.c

BINARIES  += app
SOURCES   += app.c
TESTSRC   += needs-tool.c
EOT
echo 'int main(void) { return 0; }' > src/tool.c
echo 'int main(void) { return 0; }' > src/app.c

# Written with echo rather than in a heredoc: a "#" in the first
# column of this file is a directive for this file.
echo '#pconfigure TESTDEPS  +=  testexec/tool' > test/app/needs-tool.c
cat >>test/app/needs-tool.c <<'EOT'
int main(void) { return 0; }
EOT

$PTEST_BINARY $PCONFIGURE_ARGS
# The test itself is never built: a "#pconfigure" is no directive the
# C compiler knows, and what matters here is only that the TESTDEPS was
# read and landed on the check.
grep '^check/app/needs-tool.c:.*testexec/tool' Makefile
