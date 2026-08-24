#include "harness_start.bash"

mkdir -p src test/suite test/other

# DEPTESTS is TESTDEPS' opposite number: TESTDEPS waits for something
# the build makes, and this waits for something another test makes.
# The case it exists for is state that costs too much to produce twice
# -- one test builds it, and the tests after it read what it left
# behind rather than each making their own.
#
# What pconfigure promises is only the order and the re-run.  Handing
# the state along is between the two tests, and so is deciding what a
# failed predecessor means, both of which this pins down below.
#
# The two waiting tests are written in different languages on purpose:
# a bash test and a C test have their check targets emitted by
# languages/bash.c++ and languages/cxx.c++ respectively, which are two
# separate copies of the same handful of lines, and a fix that only
# lands in one of them looks entirely correct until somebody writes a
# test in the other language.
cat >Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash

BINARIES  += suite
SOURCES   += suite.c
TESTSRC   += makes-state.bash
TESTSRC   += reads-state.bash
DEPTESTS  += makes-state.bash
TESTSRC   += reads-state.c
DEPTESTS  += makes-state.bash

BINARIES  += other
SOURCES   += other.c
TESTSRC   += alone.bash
EOF

cat >src/suite.c <<EOF
int main(void) { return 0; }
EOF

cat >src/other.c <<EOF
int main(void) { return 0; }
EOF

# What a test leaves in $PTEST_TMPDIR is what gets collected, so this
# is the whole of how the state gets handed along.
cat >test/suite/makes-state.bash <<'EOF'
echo "expensive" > "$PTEST_TMPDIR/state"
EOF

# ... and $PTEST_CHECKDIR is where the successor finds it: the
# directory this test's own result is about to land in, which is where
# every other test of the same target lands too.  It's absolute,
# because a test runs wherever make was run and that is not something
# it gets to assume.
cat >test/suite/reads-state.bash <<'EOF'
test -n "$PTEST_CHECKDIR"
case "$PTEST_CHECKDIR" in /*) ;; *) exit 1 ;; esac
test "$(tar -xOf "$PTEST_CHECKDIR/makes-state.bash" state)" = "expensive"
EOF

cat >test/suite/reads-state.c <<EOF
int main(void) { return 0; }
EOF

cat >test/other/alone.bash <<'EOF'
true
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

##############################################################################
# Configuring                                                                #
##############################################################################
# The check target of the test being waited for is an ordinary
# prerequisite of the check targets doing the waiting.  That is the
# whole mechanism: everything else in this file is a consequence of
# this one line being in the Makefile twice.
grep -q "^check/suite/reads-state.bash:.* check/suite/makes-state.bash$" Makefile
grep -q "^check/suite/reads-state.c:.* check/suite/makes-state.bash$" Makefile

# The test being waited for doesn't wait for anything, and a target
# that never asked for any of this doesn't either.  The second is
# worth pinning down because a DEPTESTS that leaked onto the target
# the way a TESTDEPS does would reach every test under it.
if grep -q "^check/suite/makes-state.bash:.* check/suite" Makefile
then
    exit 1
fi
if grep -q "^check/other/alone.bash:.* check/" Makefile
then
    exit 1
fi

##############################################################################
# Running                                                                    #
##############################################################################
make $MAKE_ARGS check

# ptest reports a test's exit status by putting it in the tarball it
# leaves behind, so this is the tests above saying they found the
# state and that it was the state they expected, rather than make
# saying it got as far as starting them.
test "$(tar -xOf check/suite/makes-state.bash ptest__return)" = "0"
test "$(tar -xOf check/suite/reads-state.bash ptest__return)" = "0"
test "$(tar -xOf check/suite/reads-state.c ptest__return)" = "0"
test "$(tar -xOf check/other/alone.bash ptest__return)" = "0"

##############################################################################
# Rebuilding                                                                 #
##############################################################################
# A prerequisite is a prerequisite in both directions: re-running the
# test that makes the state has to re-run the tests that read it, or a
# test that passed against state that has since been remade goes on
# claiming to have passed.  The sleep is for mtime granularity, which
# is a second on plenty of filesystems.
sleep 2s
touch test/suite/makes-state.bash
make $MAKE_ARGS check > second.out

grep -q "CHECK.makes-state.bash" second.out
grep -q "CHECK.reads-state.bash" second.out
grep -q "CHECK.reads-state.c" second.out

# ... and a test that never named it doesn't get dragged along with
# them, which is the same negative as above asked of make rather than
# of grep.
if grep -q "CHECK.alone.bash" second.out
then
    exit 1
fi

# The other direction isn't a dependency at all: re-running a test
# that waits doesn't re-run the one it waited for.
sleep 2s
touch test/suite/reads-state.bash
make $MAKE_ARGS check > third.out

grep -q "CHECK.reads-state.bash" third.out
if grep -q "CHECK.makes-state.bash" third.out
then
    exit 1
fi

##############################################################################
# A predecessor that fails                                                   #
##############################################################################
# A test that fails is still a test that finished, and its check
# target is a target that was made -- so the tests waiting on it run.
# That's deliberate: only the tests know whether the state they wanted
# got made, and "make report" is what has an opinion about the result.
# A build where one failing test silently skipped the rest of its
# suite would report a much smaller failure than actually happened.
cat >test/suite/makes-state.bash <<'EOF'
echo "expensive" > "$PTEST_TMPDIR/state"
exit 1
EOF

# "make check" ends by reporting, so a failing test makes it fail --
# which is a different thing from the failing test's own check target
# having failed, and is why this one is expected to.
sleep 2s
if make $MAKE_ARGS check > failed.out 2>&1
then
    exit 1
fi
cat failed.out

grep -q "CHECK.makes-state.bash" failed.out
grep -q "CHECK.reads-state.bash" failed.out
grep -q "CHECK.reads-state.c" failed.out

# The state was still handed along, since the test wrote it before it
# failed -- which is exactly the case where leaving the decision to
# the successor is worth something.
test "$(tar -xOf check/suite/makes-state.bash ptest__return)" = "1"
test "$(tar -xOf check/suite/reads-state.bash ptest__return)" = "0"

# ... and the failure is not lost: "make report" is where it turns up.
if make $MAKE_ARGS report > report.out 2>&1
then
    exit 1
fi
cat report.out
grep -q "FAIL.*makes-state.bash" report.out

exit 0
