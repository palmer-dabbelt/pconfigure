#include "harness_start.bash"

# The orders a DEPTESTS isn't allowed to ask for.  Every one of these
# is a thing that make has some answer to, and none of make's answers
# name the Configfile line that caused it -- which is the whole reason
# for asking these questions here instead.

# Rebuilt from scratch for each case, since the point of every one of
# them is that no Makefile comes out the far side.
setup() {
    rm -rf case
    mkdir -p case/src case/test/suite case/test/other

    cat >case/src/suite.c <<EOF
int main(void) { return 0; }
EOF
    cat >case/src/other.c <<EOF
int main(void) { return 0; }
EOF

    for t in a b c
    do
        echo true > "case/test/suite/$t.bash"
    done
    echo true > case/test/other/far.bash
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
# With no test open above it                                                 #
##############################################################################
# This is the one that makes DEPTESTS different in shape from
# TESTDEPS, and the reason is in the message: a DEPTESTS on the target
# would be read by every test underneath it, and one of those tests is
# the one being waited for.  There is no way to write that down that
# means anything, so it's refused rather than given some reading
# nobody asked for.
setup
cat >case/Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash

BINARIES  += suite
DEPTESTS  += a.bash
SOURCES   += suite.c
TESTSRC   += a.bash
TESTSRC   += b.bash
EOF

refuses
grep -q "DEPTESTS with no test open above it" out
grep -q "TESTS or TESTSRC line of the test that does the waiting" out

# The same line after the target was closed rather than before it was
# opened.  A DEPTESTS that quietly attached itself to whatever context
# happened to be on the stack would be worse than one that says
# nothing is open.
setup
cat >case/Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash

BINARIES  += suite
SOURCES   += suite.c
TESTSRC   += a.bash

BINARIES  += other
SOURCES   += other.c
DEPTESTS  += a.bash
EOF

refuses
grep -q "DEPTESTS with no test open above it" out

##############################################################################
# Naming a test of some other target                                         #
##############################################################################
# Two tests that share state are one suite however they got written,
# and a suite belongs to whoever has all of it.  Ordering across two
# targets would be an order that only holds when one make happens to
# build both, so the message says where such a test really goes.
setup
cat >case/Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash

BINARIES  += other
SOURCES   += other.c
TESTSRC   += far.bash

BINARIES  += suite
SOURCES   += suite.c
TESTSRC   += a.bash
DEPTESTS  += ../other/far.bash
EOF

refuses
grep -q "DEPTESTS can't reach outside the target" out
grep -q "put both under a PHONY" out

# An absolute path is out of the target too, and for the same reason.
setup
cat >case/Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash

BINARIES  += suite
SOURCES   += suite.c
TESTSRC   += a.bash
DEPTESTS  += /check/suite/b.bash
EOF

refuses
grep -q "DEPTESTS can't reach outside the target" out

##############################################################################
# Naming a test that nobody wrote                                            #
##############################################################################
# The shape this mistake almost always comes in is a DEPTESTS reaching
# for a test of another target without the "../" that would have got
# it refused above.  What make would say is "No rule to make target",
# naming a path in a check directory and nothing about the Configfile.
setup
cat >case/Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash

BINARIES  += other
SOURCES   += other.c
TESTSRC   += far.bash

BINARIES  += suite
SOURCES   += suite.c
TESTSRC   += a.bash
DEPTESTS  += far.bash
EOF

refuses
grep -q "DEPTESTS waits for 'far.bash', which is no test of this target" out

# ... and the message says the target it would have been, since the
# gap between the name written and the path it turned into is usually
# where the mistake is visible.
grep -q "check/suite/far.bash" out

##############################################################################
# Waiting in a circle                                                        #
##############################################################################
# A test that waits for itself.  make drops the edge and carries on,
# so the build works and the order silently isn't the one that was
# asked for -- which is the worst way for this to go wrong, since
# being sure of the order is the whole point of writing a DEPTESTS.
setup
cat >case/Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash

BINARIES  += suite
SOURCES   += suite.c
TESTSRC   += a.bash
DEPTESTS  += a.bash
EOF

refuses
grep -q "DEPTESTS waits for itself" out

# Three of them in a ring, which is the same thing said less
# obviously.  The message walks the circle, because "there is a cycle"
# on its own leaves somebody to find it.
setup
cat >case/Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash

BINARIES  += suite
SOURCES   += suite.c
TESTSRC   += a.bash
DEPTESTS  += c.bash
TESTSRC   += b.bash
DEPTESTS  += a.bash
TESTSRC   += c.bash
DEPTESTS  += b.bash
EOF

refuses
grep -q "wait in a circle" out
grep -q "check/suite/a.bash waits for check/suite/c.bash" out
grep -q "check/suite/c.bash waits for check/suite/b.bash" out
grep -q "check/suite/b.bash waits for check/suite/a.bash" out

##############################################################################
# A chain that isn't a circle                                                #
##############################################################################
# The negative that keeps the check above from being a check that
# nothing waits for anything: a long chain, and a test waited for by
# two others, are both perfectly ordinary and have to configure.
setup
cat >case/Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash

BINARIES  += suite
SOURCES   += suite.c
TESTSRC   += a.bash
TESTSRC   += b.bash
DEPTESTS  += a.bash
TESTSRC   += c.bash
DEPTESTS  += a.bash
DEPTESTS  += b.bash
EOF

(cd case && $PTEST_BINARY $PCONFIGURE_ARGS)
test -e case/Makefile

# A test can wait for more than one, and both of them land.
grep -q "^check/suite/c.bash:.* check/suite/a.bash check/suite/b.bash$" case/Makefile

exit 0
