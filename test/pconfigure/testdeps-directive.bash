#include "harness_start.bash"

mkdir -p src test/uses-tool test/plain

# A test that needs a program built before it runs can say so in the
# test, with a "#pconfigure" line.  That's the same shape as the
# include above: a statement about the file it's written in, read by
# whoever is building that file.
#
# The Configfile below is what it saves.  A TESTDEPS written there
# lands on the target, so it reaches every test underneath -- and a
# target with one test that needs the tool and one that doesn't has
# nowhere to put the line that says which.  Here each test carries its
# own answer, and the Configfile says nothing about it at all.
#
# Every directive below is written with "echo" rather than inside a
# heredoc.  A '#' in the first column of this file is a directive for
# this file, which is a test of pconfigure that pconfigure builds, and
# one written into a heredoc would be read on the way past.
cat >Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash

TESTEXECS += tool
SOURCES   += tool.c

BINARIES  += uses-tool
SOURCES   += uses-tool.c
TESTSRC   += finds-tool.bash
TESTSRC   += includes-it.bash

BINARIES  += plain
SOURCES   += plain.c
TESTSRC   += plain.bash
EOF

cat >src/tool.c <<EOF
  #include <stdio.h>
int main(void) { printf("tool\n"); return 0; }
EOF

cat >src/uses-tool.c <<EOF
int main(void) { return 0; }
EOF

cat >src/plain.c <<EOF
int main(void) { return 0; }
EOF

# The path is written the way a TESTDEPS in the Configfile writes one:
# from the top of the project, rather than from the test's own
# directory.  What it names is something the project builds, and where
# the project builds it is not a question about where the test that
# waits for it happens to live.
echo '#pconfigure TESTDEPS += testexec/tool' > test/uses-tool/finds-tool.bash
cat >>test/uses-tool/finds-tool.bash <<'EOF'
tool="$(dirname "$PTEST_BINARY")/../testexec/tool"
test -x "$tool"
test "$($tool)" = "tool"
EOF

# The same thing said in a file the test includes, which is where it
# belongs once several tests share the code that needs the tool: the
# helper knows what it needs, and a test that pulls the helper in gets
# the dependency along with the code.
echo '#pconfigure TESTDEPS += testexec/tool' > test/uses-tool/needs-tool.bash
cat >>test/uses-tool/needs-tool.bash <<'EOF'
run_tool() {
    "$(dirname "$PTEST_BINARY")/../testexec/tool"
}
EOF

echo '#include "needs-tool.bash"' > test/uses-tool/includes-it.bash
cat >>test/uses-tool/includes-it.bash <<'EOF'
test "$(run_tool)" = "tool"
EOF

cat >test/plain/plain.bash <<'EOF'
true
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

##############################################################################
# Configuring                                                                #
##############################################################################
# Both tests wait on the tool: the one that said so itself, and the one
# that said so by including a file that did.
grep -q "^check/uses-tool/finds-tool.bash:.* testexec/tool$" Makefile
grep -q "^check/uses-tool/includes-it.bash:.* testexec/tool$" Makefile

# The test that never asked doesn't wait, which is the half a
# Configfile can't write: a TESTDEPS up there lands on the target, and
# every test under it reads it.
if grep -q "^check/plain/plain.bash:.*testexec/tool" Makefile
then
    exit 1
fi

##############################################################################
# Building                                                                   #
##############################################################################
# "make check" with no "make" in front of it: "check" builds what the
# tests need and nothing else, so the tool only exists afterwards if
# the directive put it there.
make $MAKE_ARGS check
test -x testexec/tool

# ptest reports a test's exit status by putting it in the tarball it
# leaves behind, so this is the tests above saying they found the tool
# and ran it, rather than make saying it got as far as starting them.
test "$(tar -xOf check/uses-tool/finds-tool.bash ptest__return)" = "0"
test "$(tar -xOf check/uses-tool/includes-it.bash ptest__return)" = "0"
test "$(tar -xOf check/plain/plain.bash ptest__return)" = "0"

##############################################################################
# Rebuilding                                                                 #
##############################################################################
# A prerequisite is a prerequisite in both directions: changing the
# tool has to re-run the tests that were waiting on it, or a test that
# passed against the old one goes on claiming to have passed.  The
# sleep is for mtime granularity, which is a second on plenty of
# filesystems.
sleep 2s
touch src/tool.c
make $MAKE_ARGS check > second.out

grep -q "CHECK.finds-tool.bash" second.out
grep -q "CHECK.includes-it.bash" second.out

if grep -q "CHECK.plain.bash" second.out
then
    exit 1
fi

exit 0
