#include "harness_start.bash"

mkdir -p src test/top sub/src sub/test/inner

# A suite that includes another runs that suite's tests, and a suite
# of one name is one suite across the whole build -- so the two
# together have to mean that a subproject's test which joined "smoke"
# is in the top's "overnight".  Resolving the inclusion inside each
# project instead answers it against that project's tests alone, and
# what comes out is a "make check-overnight" that quietly runs fewer
# tests than the "make check-smoke" it was told to include.
cat >Configfile <<EOF
LANGUAGES           += c
LANGUAGES           += bash

SUBPROJECTS         += sub

TEST_SUITES         += smoke

TEST_SUITES         += overnight
INCLUDE_TEST_SUITES += smoke

BINARIES            += top
SOURCES             += top.c
TESTSRC[smoke]      += top-smoke.bash
EOF

cat >sub/Configfile <<EOF
LANGUAGES        += c
LANGUAGES        += bash

TEST_SUITES      += smoke

BINARIES         += inner
SOURCES          += inner.c
TESTSRC[smoke]   += inner-smoke.bash
EOF

cat >src/top.c <<EOF
int main(void) { return 0; }
EOF

cat >sub/src/inner.c <<EOF
int main(void) { return 0; }
EOF

echo true > test/top/top-smoke.bash
echo true > sub/test/inner/inner-smoke.bash

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

##############################################################################
# The suite that includes another                                            #
##############################################################################
# The subproject never heard of "overnight" and doesn't have to have:
# it put its test in "smoke", and "overnight" was told it runs
# "smoke".
grep -q "^obj/check-suite-smoke-done: check/top/top-smoke.bash sub/check/inner/inner-smoke.bash$" Makefile
grep -q "^obj/check-suite-overnight-done: check/top/top-smoke.bash sub/check/inner/inner-smoke.bash$" Makefile

make $MAKE_ARGS check-overnight
make $MAKE_ARGS report-overnight > overnight.out
cat overnight.out

grep -q "^NRUN	2$" overnight.out
grep -q "PASS	top/top-smoke.bash" overnight.out
grep -q "PASS	sub/inner/inner-smoke.bash" overnight.out

##############################################################################
# The other direction                                                        #
##############################################################################
# The subproject is the one doing the including this time.  A suite is
# a name make can be asked for and the make that gets asked is the one
# at the top, so the rule that turns up there has to run the top's
# "smoke" tests too -- the inclusion was written a directory down, but
# there is only one "smoke" for it to be about.
rm -rf check obj sub/check sub/obj

sed '/^TEST_SUITES         += overnight$/d;/^INCLUDE_TEST_SUITES += smoke$/d' \
    Configfile > Configfile.new
mv Configfile.new Configfile
cat Configfile

cat >>sub/Configfile <<EOF

TEST_SUITES         += overnight
INCLUDE_TEST_SUITES += smoke
EOF
cat sub/Configfile

$PTEST_BINARY $PCONFIGURE_ARGS
grep -q "^obj/check-suite-overnight-done: check/top/top-smoke.bash sub/check/inner/inner-smoke.bash$" Makefile

##############################################################################
# What "make check" means                                                    #
##############################################################################
# The same question asked of the line that refuses an empty suite: the
# top has no test of its own in anything, and the suite its "make
# check" means is full anyway, a directory down and through an
# inclusion.
rm -rf check obj sub/check sub/obj Makefile

cat >Configfile <<EOF
LANGUAGES           += c
LANGUAGES           += bash

SUBPROJECTS         += sub

TEST_SUITES         += smoke

TEST_SUITES         += overnight
INCLUDE_TEST_SUITES += smoke

DEFAULT_TEST_SUITE   = overnight

BINARIES            += top
SOURCES             += top.c
EOF

sed '/TEST_SUITES         += overnight/d;/INCLUDE_TEST_SUITES += smoke/d' \
    sub/Configfile > sub/Configfile.new
mv sub/Configfile.new sub/Configfile
cat sub/Configfile

$PTEST_BINARY $PCONFIGURE_ARGS
grep -q "^obj/check-suite-overnight-done: sub/check/inner/inner-smoke.bash$" Makefile

make $MAKE_ARGS check
make $MAKE_ARGS report > default.out
cat default.out

grep -q "^NRUN	1$" default.out
grep -q "PASS	sub/inner/inner-smoke.bash" default.out

##############################################################################
# The subproject's test that named no suite                                  #
##############################################################################
# The two halves above compose, and until this case nothing asserted
# that they do.  A test written with no suite is in every suite the
# project that wrote it declared -- test-suites-unnamed.bash, which has
# no subproject in it -- and an inclusion is resolved over the whole
# build, which is the first case here, whose subproject names its
# test's suite outright.  Put together they say a subproject that
# declared only "smoke" and wrote its test without a name has put that
# test in "smoke", and the top's "overnight" runs it.
#
# Worth its own case rather than left to inference, because the two
# ways of getting it wrong land on opposite sides and both look
# reasonable from one file.  Resolving the inclusion per project loses
# the test -- 46df8ee ("pconfigure: Resolve an INCLUDE_TEST_SUITES
# across the whole build") -- while reading "no suite" as "every suite
# in the build" puts it in "overnight" directly, which is the answer
# the third case of test-suites-subprojects.bash refuses from the
# other direction.  Only a case with an unnamed test a directory down
# and an inclusion at the top can tell the right answer from either.
rm -rf check obj sub/check sub/obj Makefile

cat >Configfile <<EOF
LANGUAGES           += c
LANGUAGES           += bash

SUBPROJECTS         += sub

TEST_SUITES         += smoke

TEST_SUITES         += overnight
INCLUDE_TEST_SUITES += smoke

BINARIES            += top
SOURCES             += top.c
# Named, so that the subproject's unnamed test is the only thing the
# assertions below are about: an unnamed test up here would join both
# of the top's suites and be in "overnight" without any inclusion.
TESTSRC[smoke]      += top-smoke.bash
EOF

cat >sub/Configfile <<EOF
LANGUAGES   += c
LANGUAGES   += bash

TEST_SUITES += smoke

BINARIES    += inner
SOURCES     += inner.c
TESTSRC     += inner-any.bash
EOF
cat sub/Configfile

echo true > sub/test/inner/inner-any.bash

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

grep -q "^obj/check-suite-smoke-done: check/top/top-smoke.bash sub/check/inner/inner-any.bash$" Makefile
grep -q "^obj/check-suite-overnight-done: check/top/top-smoke.bash sub/check/inner/inner-any.bash$" Makefile

# And the rule has to be one somebody can run, because a suite that
# resolves to fewer tests than it should still reports that everything
# in it passed -- which is the whole reason this file exists.
make $MAKE_ARGS check-overnight
make $MAKE_ARGS report-overnight > unnamed.out
cat unnamed.out

grep -q "^NRUN	2$" unnamed.out
grep -q "PASS	top/top-smoke.bash" unnamed.out
grep -q "PASS	sub/inner/inner-any.bash" unnamed.out

exit 0
