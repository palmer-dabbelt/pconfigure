#include "harness_start.bash"

# A perl test is a script just as a bash one is: pperlc reads it line
# by line, and a '#' starts a comment.  The "/" and "*" that end a
# glob are a glob in perl too, but read as C they open a comment that
# nothing closes, and a "#pconfigure" under the glob is blanked with
# everything else after it.  The test would then run before the
# program it said it needed was built.
mkdir -p src test/main

cat >Configfile <<'EOF'
LANGUAGES += c
LANGUAGES += perl

TESTEXECS += tool
SOURCES   += tool.c

BINARIES  += main
SOURCES   += main.c
TESTSRC   += uses-tool.pl
EOF

echo 'int main(void) { return 0; }' > src/tool.c
echo 'int main(void) { return 0; }' > src/main.c

# Written with echo rather than a heredoc, since a '#' in the first
# column of this file is read by the pconfigure that builds it.
{
    echo 'my @f = glob("$ENV{HOME}/*");'
    echo '#pconfigure TESTDEPS += testexec/tool'
    echo 'exit 0;'
} > test/main/uses-tool.pl

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

grep -q "^check/main/uses-tool.pl:.* testexec/tool" Makefile
