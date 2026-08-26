#include "harness_start.bash"

mkdir -p src test/suite

# A project that can't run all of its tests everywhere has to be able
# to say which ones a given machine can run, and "make check" can't be
# that answer: it has to mean the same thing wherever it's typed.  A
# suite is a name for some of the tests, and this is what the name
# gets you -- a "make check-<name>" that runs those tests and a "make
# report-<name>" that reports on that run rather than on whatever
# happens to be sitting in the check directory.
cat >Configfile <<EOF
LANGUAGES           += c
LANGUAGES           += bash

TEST_SUITES         += quick

TEST_SUITES         += network

TEST_SUITES         += everything
INCLUDE_TEST_SUITES += quick
INCLUDE_TEST_SUITES += network

TEST_SUITES         += nobody

BINARIES            += suite
SOURCES             += suite.c
TESTSRC[quick]      += fast.bash
TESTSRC[quick]      += needs-slow.bash
DEPTESTS            += slow.bash
TESTSRC[network]    += slow.bash
TESTSRC[network]    += only-network.bash
EOF

cat >src/suite.c <<EOF
int main(void) { return 0; }
EOF

for t in fast needs-slow slow only-network
do
    echo true > "test/suite/$t.bash"
done

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

##############################################################################
# Configuring                                                                #
##############################################################################
# A suite's stamp is what makes asking for it build the tests in it
# and nothing else, so the whole of which-tests-are-in-which-suite is
# these three lines.
grep -q "^obj/check-quick-done: check/suite/fast.bash check/suite/needs-slow.bash check/suite/slow.bash$" Makefile
grep -q "^obj/check-network-done: check/suite/only-network.bash check/suite/slow.bash$" Makefile
grep -q "^obj/check-everything-done: check/suite/fast.bash check/suite/needs-slow.bash check/suite/only-network.bash check/suite/slow.bash$" Makefile

# "slow.bash" is in "quick" because a test in "quick" waits for it.
# make builds what a DEPTESTS names before it runs the test that
# waits, so a suite that didn't claim it would run it anyway and then
# not say so.
grep -q "^check/suite/needs-slow.bash:.* check/suite/slow.bash$" Makefile

# A suite nobody joined still has its rules: the name is a promise
# about what it means, and an empty run keeps it.
grep -q "^obj/check-nobody-done:$" Makefile

# Both of the rules that get typed are names rather than files.
grep -q "^.PHONY: check-quick$" Makefile
grep -q "^check-quick: obj/check-quick-report-quiet$" Makefile
grep -q "^.PHONY: report-quick$" Makefile
grep -q "^report-quick: obj/check-quick-report$" Makefile

# The report is over the results the suite ran rather than over the
# directory they landed in, which is the only way it could be: the
# tarballs of two suites land in the same place.
grep -q "check-suite quick --check-result check/suite/fast.bash" Makefile

##############################################################################
# Running one suite                                                          #
##############################################################################
make $MAKE_ARGS check-quick

# The tests in the suite ran ...
test -e check/suite/fast.bash
test -e check/suite/needs-slow.bash
test -e check/suite/slow.bash

# ... and the test that isn't in it didn't.  This is the whole point:
# a machine that can't run "only-network.bash" can still be asked for
# everything else without being told about it one test at a time.
test ! -e check/suite/only-network.bash

make $MAKE_ARGS report-quick > quick.out
cat quick.out
grep -q "^NRUN	3$" quick.out
grep -q "PASS	suite/fast.bash" quick.out
if grep -q "only-network.bash" quick.out
then
    exit 1
fi

##############################################################################
# Running another                                                            #
##############################################################################
make $MAKE_ARGS check-network
test -e check/suite/only-network.bash

make $MAKE_ARGS report-network > network.out
cat network.out
grep -q "^NRUN	2$" network.out
grep -q "PASS	suite/only-network.bash" network.out
grep -q "PASS	suite/slow.bash" network.out

# A suite that includes two others runs the tests of both, and runs
# them once: this is the same four results, reported under a third
# name.
make $MAKE_ARGS report-everything > everything.out
cat everything.out
grep -q "^NRUN	4$" everything.out

# ... and one nobody joined runs none of them.
make $MAKE_ARGS check-nobody
make $MAKE_ARGS report-nobody > nobody.out
cat nobody.out
grep -q "No tests" nobody.out

##############################################################################
# Running all of them                                                        #
##############################################################################
# "make check" is untouched by any of this: it means every test in the
# project, the way it always did.
make $MAKE_ARGS check
make $MAKE_ARGS report > all.out
cat all.out
grep -q "^NRUN	4$" all.out

##############################################################################
# Re-running one                                                             #
##############################################################################
# A suite's stamp is a stamp like any other, so a test that changed
# gets run again and a test that didn't doesn't.  The sleep is for
# mtime granularity, which is a second on plenty of filesystems.
sleep 2s
touch test/suite/fast.bash
make $MAKE_ARGS check-quick > second.out

grep -q "CHECK.fast.bash" second.out
if grep -q "CHECK.only-network.bash" second.out
then
    exit 1
fi

##############################################################################
# A failure inside one                                                       #
##############################################################################
# A suite reports what its own tests did, so a test failing outside it
# is not its business -- and a test failing inside it is.
cat >test/suite/only-network.bash <<'EOF'
exit 1
EOF

sleep 2s
if make $MAKE_ARGS check-network > failed.out 2>&1
then
    exit 1
fi
cat failed.out

make $MAKE_ARGS check-quick

exit 0
