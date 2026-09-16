#include "harness_start.bash"

mkdir -p src test/suite

# $PTEST_SCRATCH_DIR is $PTEST_TMPDIR's opposite number: the temp
# directory is emptied for every run and every byte left in it is
# tarred into the test's result, and this one is neither.
#
# What it is for is the fixture that is too big to copy around -- a
# disk image, a populated tree, a rootfs.  Collecting one of those
# costs as much as the test did, and the copy is of something that
# already exists on disk; the system temp is usually a different
# volume from the tree as well, so a copy-on-write clone of a fixture
# stops being cheap the moment it is handed through there.
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
TESTSRC   += makes-fixture.bash
TESTSRC   += reads-fixture.bash
DEPTESTS  += makes-fixture.bash
TESTSRC   += reads-fixture.c
DEPTESTS  += makes-fixture.bash
EOF

cat >src/suite.c <<EOF
int main(void) { return 0; }
EOF

# The producer: one file in each directory, so that what happens to
# them afterwards can be told apart.  The marker in the scratch
# directory is also how the re-run below sees whether it survived, so
# it is written only when it isn't already there.
cat >test/suite/makes-fixture.bash <<'EOF'
test -n "$PTEST_SCRATCH_DIR"
case "$PTEST_SCRATCH_DIR" in /*) ;; *) exit 1 ;; esac
test -d "$PTEST_SCRATCH_DIR"

echo "collected" > "$PTEST_TMPDIR/small"
if ! test -e "$PTEST_SCRATCH_DIR/fixture"
then
    echo "expensive" > "$PTEST_SCRATCH_DIR/fixture"
fi
EOF

# The consumer.  A test's own scratch is $PTEST_SCRATCH_DIR, and a
# predecessor's is its sibling -- exactly the way $PTEST_CHECKDIR is
# the directory every test of the same target leaves its result in.
# That is the whole of how a fixture gets handed along: no copy, and
# nothing that grows with how big the fixture is.
cat >test/suite/reads-fixture.bash <<'EOF'
test -n "$PTEST_SCRATCH_DIR"
case "$PTEST_SCRATCH_DIR" in /*) ;; *) exit 1 ;; esac
test -d "$PTEST_SCRATCH_DIR"

# What it left there, not what it said -- the harness below is what
# checks the contents.  A consumer that pinned the exact bytes would
# be asserting the producer's business as well as its own, and the
# re-run below rewrites them on purpose.
test -s "$(dirname "$PTEST_SCRATCH_DIR")/makes-fixture.bash.scratch/fixture"
EOF

cat >test/suite/reads-fixture.c <<'EOF'
#include <stdlib.h>
#include <string.h>

int main(void)
{
    const char *scratch = getenv("PTEST_SCRATCH_DIR");

    if (scratch == NULL)
        return 1;
    if (strlen(scratch) == 0)
        return 1;
    if (scratch[0] != '/')
        return 1;

    return 0;
}
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

##############################################################################
# Configuring                                                                #
##############################################################################
# The scratch directory is named after the test and sits beside the
# test's own compiled self under $OBJDIR -- not in the check
# directory, which is the obvious place and is the one place it must
# not be: "make report" walks a check directory with find and reads
# every file it lands on as a result tarball.
grep -q -- "--scratchdir obj/check/suite/makes-fixture.bash.scratch" Makefile
grep -q -- "--scratchdir obj/check/suite/reads-fixture.bash.scratch" Makefile
grep -q -- "--scratchdir obj/check/suite/reads-fixture.c.scratch" Makefile

# "make clean" removes it along with the test it belongs to.  A rule
# that leaves something behind under a name nothing cleans is what
# fills a disk, and the clean helper is generated from the target's
# own name -- so the scratch has to be named there outright.
grep -q "^__pconfigure__clean-check/suite/makes-fixture.bash:; @rm -fr check/suite/makes-fixture.bash obj/check/suite/makes-fixture.bash.scratch$" Makefile

##############################################################################
# Running                                                                    #
##############################################################################
make $MAKE_ARGS check

test "$(tar -xOf check/suite/makes-fixture.bash ptest__return)" = "0"
test "$(tar -xOf check/suite/reads-fixture.bash ptest__return)" = "0"
test "$(tar -xOf check/suite/reads-fixture.c ptest__return)" = "0"

# The directory is real, and what went in it stayed there rather than
# being removed with the temp directory when the test finished.
test "$(cat obj/check/suite/makes-fixture.bash.scratch/fixture)" = "expensive"

# ... and it is NOT in the result, which is the entire point.  The
# small file written beside it in $PTEST_TMPDIR is, which is what says
# this test is looking at a working collection rather than at one that
# collected nothing at all.
tar -tf check/suite/makes-fixture.bash | grep -q '^small$'
if tar -tf check/suite/makes-fixture.bash | grep -q 'fixture'
then
    exit 1
fi

##############################################################################
# Re-running                                                                 #
##############################################################################
# Emptied for every run is what $PTEST_TMPDIR promises and this one
# does not: a fixture too expensive to collect is usually too
# expensive to make twice, so it survives into the next run and the
# test that wants it clean is the one that clears it.  The marker is
# only written when it is absent, so it having changed is the producer
# having found an empty directory.
sleep 2s
echo "reused" > obj/check/suite/makes-fixture.bash.scratch/fixture
touch test/suite/makes-fixture.bash
make $MAKE_ARGS check > second.out

grep -q "CHECK.makes-fixture.bash" second.out
test "$(cat obj/check/suite/makes-fixture.bash.scratch/fixture)" = "reused"

##############################################################################
# Cleaning                                                                   #
##############################################################################
make $MAKE_ARGS clean

if test -e obj/check/suite/makes-fixture.bash.scratch
then
    exit 1
fi
if test -e obj/check/suite/reads-fixture.c.scratch
then
    exit 1
fi
