#include "harness_start.bash"

mkdir -p src test/top sub/src sub/test/inner

# A suite is a name make can be asked for, and the make that gets
# asked is whichever one somebody ran -- so a build with subprojects
# has to answer for its children's suites when it's run at the top,
# and for its own when it's run inside one.  Which of those happened
# is not something a Configfile can know, so both have to work.
cat >Configfile <<EOF
LANGUAGES        += c
LANGUAGES        += bash

SUBPROJECTS      += sub

TEST_SUITES      += network

BINARIES         += top
SOURCES          += top.c
TESTSRC[network] += top-net.bash
TESTSRC          += top-any.bash
EOF

cat >sub/Configfile <<EOF
LANGUAGES        += c
LANGUAGES        += bash

TEST_SUITES      += network

BINARIES         += inner
SOURCES          += inner.c
TESTSRC[network] += inner-net.bash
EOF

cat >src/top.c <<EOF
int main(void) { return 0; }
EOF

cat >sub/src/inner.c <<EOF
int main(void) { return 0; }
EOF

echo true > test/top/top-net.bash
echo true > test/top/top-any.bash
echo true > sub/test/inner/inner-net.bash

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

##############################################################################
# From the top                                                               #
##############################################################################
# Two projects that both declare a suite of one name have one suite as
# far as make is concerned, because there is one rule with that name
# to run.
grep -q "^obj/check-suite-network-done: check/top/top-any.bash check/top/top-net.bash sub/check/inner/inner-net.bash$" Makefile

make $MAKE_ARGS check-network
make $MAKE_ARGS report-network > top.out
cat top.out

grep -q "^NRUN	3$" top.out
grep -q "PASS	top/top-net.bash" top.out
grep -q "PASS	sub/inner/inner-net.bash" top.out

##############################################################################
# From inside the subproject                                                 #
##############################################################################
# The subproject's own copy of the rule, which only exists when make
# was run there -- the same way its "make check" only exists there.
(cd sub && make $MAKE_ARGS check-network)
(cd sub && make $MAKE_ARGS report-network > inner.out)
cat sub/inner.out

grep -q "^NRUN	1$" sub/inner.out
grep -q "PASS	inner/inner-net.bash" sub/inner.out

##############################################################################
# A suite only the subproject has                                            #
##############################################################################
# The rule still turns up at the top, since that's where somebody
# would type it.  What it runs is the subproject's tests and nothing
# else: a project that never declared the suite has no opinion about
# which of its tests could run in it, and "all of them" is an opinion.
rm -rf check obj sub/check sub/obj
sed '/TEST_SUITES/d' Configfile > Configfile.new
mv Configfile.new Configfile
sed 's/TESTSRC\[network\]/TESTSRC         /' Configfile > Configfile.new
mv Configfile.new Configfile
cat Configfile

$PTEST_BINARY $PCONFIGURE_ARGS
grep -q "^obj/check-suite-network-done: sub/check/inner/inner-net.bash$" Makefile

make $MAKE_ARGS check-network
test -e sub/check/inner/inner-net.bash
test ! -e check/top/top-any.bash

exit 0
