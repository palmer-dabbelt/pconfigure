#include "harness_start.bash"

mkdir -p src test/suite

# Most tests can run anywhere, and a project where each of them has to
# say so in every suite is a project where the lists drift apart the
# first time somebody adds a suite.  So a test written without a suite
# is in all of them.
#
# All of them it could run in, that is.  A test that reads what
# another test left behind can't run where that test doesn't, and the
# DEPTESTS that says so is the only thing about such a test that ever
# named a suite -- so it's what gets read.
cat >Configfile <<EOF
LANGUAGES        += c
LANGUAGES        += bash

TEST_SUITES      += network

TEST_SUITES      += quick

BINARIES         += suite
SOURCES          += suite.c
TESTSRC[network] += network-test.bash
TESTSRC          += network-test-dep.bash
DEPTESTS         += network-test.bash
TESTSRC          += chained.bash
DEPTESTS         += network-test-dep.bash
TESTSRC          += anywhere.bash
EOF

cat >src/suite.c <<EOF
int main(void) { return 0; }
EOF

for t in network-test network-test-dep chained anywhere
do
    echo true > "test/suite/$t.bash"
done

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

##############################################################################
# Configuring                                                                #
##############################################################################
# "network-test-dep.bash" named no suite and waits for a test that is
# only in "network", so "network" is the only place it can run.
# "chained.bash" waits for it in turn, which is the same answer
# arrived at a step later -- and a step is what makes this worth
# writing down, since working out the first one and stopping would
# leave the second in every suite.
grep -q "^obj/check-network-done: check/suite/anywhere.bash check/suite/chained.bash check/suite/network-test-dep.bash check/suite/network-test.bash$" Makefile

# "anywhere.bash" waits for nothing, so nothing keeps it out of a
# suite -- and it's the only one of the four that "quick" gets.
grep -q "^obj/check-quick-done: check/suite/anywhere.bash$" Makefile

##############################################################################
# Running                                                                    #
##############################################################################
make $MAKE_ARGS check-quick

test -e check/suite/anywhere.bash
test ! -e check/suite/network-test.bash
test ! -e check/suite/network-test-dep.bash
test ! -e check/suite/chained.bash

make $MAKE_ARGS report-quick > quick.out
cat quick.out
grep -q "^NRUN	1$" quick.out
grep -q "PASS	suite/anywhere.bash" quick.out

make $MAKE_ARGS check-network
test -e check/suite/network-test.bash
test -e check/suite/network-test-dep.bash
test -e check/suite/chained.bash

make $MAKE_ARGS report-network > network.out
cat network.out
grep -q "^NRUN	4$" network.out

##############################################################################
# With no suites at all                                                      #
##############################################################################
# A project that never declared a suite is every project that existed
# before there were any, and its tests are all written without one.
# There is nothing for them to be in, and "make check" runs them the
# way it always did.
rm -rf plain
mkdir -p plain/src plain/test/suite

cat >plain/Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash

BINARIES  += suite
SOURCES   += suite.c
TESTSRC   += a.bash
TESTSRC   += b.bash
EOF

cat >plain/src/suite.c <<EOF
int main(void) { return 0; }
EOF

for t in a b
do
    echo true > "plain/test/suite/$t.bash"
done

(cd plain && $PTEST_BINARY $PCONFIGURE_ARGS)

# "obj/check-all-done" is the stamp every project has had all along,
# so the thing to look for is a rule somebody could type.
if grep -q "^check-" plain/Makefile
then
    exit 1
fi
if grep -q "^report-" plain/Makefile
then
    exit 1
fi

(cd plain && make $MAKE_ARGS check)
(cd plain && make $MAKE_ARGS report > report.out)
cat plain/report.out
grep -q "^NRUN	2$" plain/report.out

exit 0
