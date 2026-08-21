#include "harness_start.bash"

mkdir -p src test/uses-tool test/plain

# TESTDEPS is DEPLIBS' opposite number: a test that wants a whole
# program built before it runs has nowhere else to say so, and until
# this landed saying it at all aborted with "Command TESTDEPS not
# implemented".  The thing being waited on is a TESTEXEC here because
# that's the shape this usually comes in -- something built for the
# tests and for nothing else -- but as far as TESTDEPS is concerned
# it's just a path, and any path this project builds would do.
#
# The TESTDEPS goes directly under the BINARIES line and above two
# TESTS, which is how anybody who reads the manual will write it.  It
# has to reach both of them: the field is set on the target's context
# and every test underneath is a copy of that context, so a TESTDEPS
# that only made it onto the first test would mean the copy dropped
# it.
cat >Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash

TESTEXECS += tool
SOURCES   += tool.c

BINARIES  += uses-tool
TESTDEPS  += testexec/tool
SOURCES   += uses-tool.c
TESTSRC   += finds-tool.bash
TESTSRC   += also-runs.c

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

# The test that actually proves the ordering, rather than proving that
# the Makefile has a line in it.  $PTEST_BINARY is an absolute path to
# the binary under test, so walking out of its directory is how a test
# names anything else the build produced.
cat >test/uses-tool/finds-tool.bash <<'EOF'
tool="$(dirname "$PTEST_BINARY")/../testexec/tool"
test -x "$tool"
test "$($tool)" = "tool"
EOF

cat >test/uses-tool/also-runs.c <<EOF
int main(void) { return 0; }
EOF

cat >test/plain/plain.bash <<'EOF'
true
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

##############################################################################
# Configuring                                                                #
##############################################################################
# Both tests wait on the tool.  The two are written in different
# languages on purpose: a bash test and a C test have their check
# targets emitted by languages/bash.c++ and languages/cxx.c++
# respectively, which are two separate copies of the same handful of
# lines, and a fix that only lands in one of them looks entirely
# correct until somebody writes a test in the other language.
grep -q "^check/uses-tool/finds-tool.bash:.* testexec/tool$" Makefile
grep -q "^check/uses-tool/also-runs.c:.* testexec/tool$" Makefile

# A target that never asked for one doesn't get one.  This is worth
# pinning down because the obvious way to get the two tests above to
# share a TESTDEPS is to hang it somewhere they can both see it, and
# the places they can both see are the same places every other target
# can see too.
if grep -q "^check/plain/plain.bash:.*testexec/tool" Makefile
then
    exit 1
fi

##############################################################################
# Building                                                                   #
##############################################################################
# "make check" with no "make" in front of it, which is the whole
# point: "check" builds what the tests need and nothing else, so the
# tool only exists afterwards if the dependency put it there.
make $MAKE_ARGS check
test -x testexec/tool

# ptest reports a test's exit status by putting it in the tarball it
# leaves behind, so this is the test above saying it found the tool
# and ran it, rather than make saying it got as far as starting it.
test "$(tar -xOf check/uses-tool/finds-tool.bash ptest__return)" = "0"
test "$(tar -xOf check/uses-tool/also-runs.c ptest__return)" = "0"
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
grep -q "CHECK.also-runs.c" second.out

# ... and the test that never named the tool doesn't get dragged along
# with them, which is the same negative as above asked of make rather
# than of grep.
if grep -q "CHECK.plain.bash" second.out
then
    exit 1
fi

exit 0
