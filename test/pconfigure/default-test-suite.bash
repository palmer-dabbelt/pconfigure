#include "harness_start.bash"

mkdir -p src test/suite

# A project with tests that can't be run everywhere wants the set that
# can be to be what happens when somebody types the two words they
# already know.  The tests that need something special are exactly the
# ones a stranger to the project shouldn't be handed by default, and
# telling them about it in the README is telling them after it broke.
cat >Configfile <<EOF
LANGUAGES          += c
LANGUAGES          += bash

TEST_SUITES        += quick

TEST_SUITES        += network

DEFAULT_TEST_SUITE  = quick

BINARIES           += suite
SOURCES            += suite.c
TESTSRC[quick]     += fast.bash
TESTSRC[network]   += slow.bash
EOF

cat >src/suite.c <<EOF
int main(void) { return 0; }
EOF

for t in fast slow
do
    echo true > "test/suite/$t.bash"
done

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

##############################################################################
# Configuring                                                                #
##############################################################################
# "make check" is the suite's rule wearing the name everybody types,
# and "make report" follows it: a report about a run that didn't
# happen is a report of whatever an earlier one left on disk.
grep -q "^check: obj/check-suite-quick-report-quiet$" Makefile
grep -q "^report: obj/check-suite-quick-report$" Makefile

# The suite still has its own names, since being able to ask for it by
# name is not something choosing it here takes away.
grep -q "^check-quick: obj/check-suite-quick-report-quiet$" Makefile
grep -q "^check-network: obj/check-suite-network-report-quiet$" Makefile

##############################################################################
# Running                                                                    #
##############################################################################
# ptest run by hand says whether what it is reporting is current, and
# the file it asks make about has to be the one "make check" builds
# here -- otherwise it warns that the build is stale every time,
# forever, on a tree that is perfectly up to date.
ptest="$(dirname "$PTEST_BINARY")/ptest"
test "$(cat obj/check-stamp)" = "obj/check-suite-quick-done"

$ptest > before.out 2>&1
cat before.out
grep -q "not up to date" before.out

make $MAKE_ARGS check

# The suite ran ...
test -e check/suite/fast.bash

# ... and the tests that aren't in it didn't, which is the whole
# point: this is a machine that can't run them.
test ! -e check/suite/slow.bash

make $MAKE_ARGS report > report.out
cat report.out
grep -q "^NRUN	1$" report.out
grep -q "PASS	suite/fast.bash" report.out

$ptest > after.out 2>&1
cat after.out
if grep -q "not up to date" after.out
then
    exit 1
fi

##############################################################################
# Asking for the rest anyway                                                 #
##############################################################################
# Choosing what "make check" means doesn't take anything away: the
# machine that can run the other tests asks for them by name.
make $MAKE_ARGS check-network
test -e check/suite/slow.bash

make $MAKE_ARGS report-network > network.out
cat network.out
grep -q "^NRUN	1$" network.out
grep -q "PASS	suite/slow.bash" network.out

##############################################################################
# Saying nothing                                                             #
##############################################################################
# A project that doesn't choose gets what it always got, which is
# every test it has.
sed '/DEFAULT_TEST_SUITE/d' Configfile > Configfile.new
mv Configfile.new Configfile
rm -rf check obj

$PTEST_BINARY $PCONFIGURE_ARGS
grep -q "^check: obj/check-report-quiet$" Makefile
test "$(cat obj/check-stamp)" = "obj/check-all-done"

make $MAKE_ARGS check
test -e check/suite/fast.bash
test -e check/suite/slow.bash

exit 0
