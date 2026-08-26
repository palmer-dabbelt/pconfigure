#include "harness_start.bash"

# The test suites a project isn't allowed to declare.  Every one of
# these produces a Makefile that looks fine and runs the wrong set of
# tests, which is the one kind of mistake a test suite can make that
# nothing downstream could ever notice: a suite with no tests in it
# and a suite whose name went somewhere else both report "no tests",
# and so does a suite nobody has joined yet.

# Rebuilt from scratch for each case, since the point of every one of
# them is that no Makefile comes out the far side.
setup() {
    rm -rf case
    mkdir -p case/src case/test/suite

    cat >case/src/suite.c <<EOF
int main(void) { return 0; }
EOF

    for t in a b
    do
        echo true > "case/test/suite/$t.bash"
    done
}

# The subshell is the assertion: "set -e" is on, so a command expected
# to fail has to be somewhere a failure isn't fatal.  It stopping
# before it wrote anything is part of what's being checked -- a
# half-configured tree is something the next command trips over.
refuses() {
    if (cd case && $PTEST_BINARY $PCONFIGURE_ARGS) > out 2>&1
    then
        exit 1
    fi
    cat out
    test ! -e case/Makefile
}

##############################################################################
# A name make couldn't be asked for                                          #
##############################################################################
# The name is what "make check-<name>" is called, so a space in it is
# two make targets, neither of which is the one that was meant.  make
# would take it apart quietly and the tests would go to whichever half
# it decided to keep.
setup
cat >case/Configfile <<EOF
LANGUAGES   += c
LANGUAGES   += bash

TEST_SUITES += needs network
EOF

refuses
grep -q "'needs network' is not a name a test suite can have" out
grep -q "letters, digits" out

# A '%' is make's wildcard, so a suite named with one is a pattern
# rule rather than a target: it matches things nobody meant and is
# never the thing that got typed.
setup
cat >case/Configfile <<EOF
LANGUAGES   += c
LANGUAGES   += bash

TEST_SUITES += net%work
EOF

refuses
grep -q "'net%work' is not a name a test suite can have" out

##############################################################################
# An include with no suite above it                                          #
##############################################################################
# A suite is declared at the top level and the lines that belong to it
# are the ones directly underneath, so an include that landed
# somewhere else has nothing above it to include into.
setup
cat >case/Configfile <<EOF
LANGUAGES           += c
LANGUAGES           += bash

INCLUDE_TEST_SUITES += quick
EOF

refuses
grep -q "INCLUDE_TEST_SUITES with no test suite open above it" out
grep -q "TEST_SUITES line of the suite that does the including" out

# The same line after a target was opened rather than before any suite
# was.  An include that quietly attached itself to whichever suite was
# declared furthest up the file would be worse than one that says
# nothing is open.
setup
cat >case/Configfile <<EOF
LANGUAGES           += c
LANGUAGES           += bash

TEST_SUITES         += quick
TEST_SUITES         += slow

BINARIES            += suite
SOURCES             += suite.c
INCLUDE_TEST_SUITES += quick
EOF

refuses
grep -q "INCLUDE_TEST_SUITES with no test suite open above it" out

##############################################################################
# Including a suite nobody declared                                          #
##############################################################################
# What make would do with this is nothing at all, and "nothing at all"
# is what an empty suite looks like too -- so this is the one place it
# can be caught.
setup
cat >case/Configfile <<EOF
LANGUAGES           += c
LANGUAGES           += bash

TEST_SUITES         += quick

TEST_SUITES         += slow
INCLUDE_TEST_SUITES += quik
EOF

refuses
grep -q "INCLUDE_TEST_SUITES names 'quik', which is no test suite of this project" out
grep -q "the suites here are: 'quick' 'slow'" out

# With one suite there is no list worth printing, so the message names
# it rather than heading a list with it.
setup
cat >case/Configfile <<EOF
LANGUAGES           += c
LANGUAGES           += bash

TEST_SUITES         += slow
INCLUDE_TEST_SUITES += quick
EOF

refuses
grep -q "the only suite here is 'slow'" out

##############################################################################
# The suites a project is allowed to declare                                 #
##############################################################################
# The negative that keeps all of the above from being checks that
# nothing configures.  A suite that includes one declared further down
# the file is deliberately fine: the suites of a project are a set,
# and nothing about them depends on the order they got written in.
setup
cat >case/Configfile <<EOF
LANGUAGES           += c
LANGUAGES           += bash

TEST_SUITES         += slow
INCLUDE_TEST_SUITES += quick

TEST_SUITES         += quick

BINARIES            += suite
SOURCES             += suite.c
TESTSRC             += a.bash
TESTSRC             += b.bash
EOF

(cd case && $PTEST_BINARY $PCONFIGURE_ARGS)
test -e case/Makefile

# Naming a suite that's already here is how a project gets back to it
# to say something more, the way a second BUILD_SYSTEMS line does --
# so this is one suite that includes two, not two suites.
setup
cat >case/Configfile <<EOF
LANGUAGES           += c
LANGUAGES           += bash

TEST_SUITES         += quick
TEST_SUITES         += network

TEST_SUITES         += slow
INCLUDE_TEST_SUITES += quick

TEST_SUITES         += slow
INCLUDE_TEST_SUITES += network

BINARIES            += suite
SOURCES             += suite.c
TESTSRC             += a.bash
EOF

(cd case && $PTEST_BINARY $PCONFIGURE_ARGS)
test -e case/Makefile

exit 0
