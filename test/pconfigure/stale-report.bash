#include "harness_start.bash"

mkdir -p src test/suite

# A report file outlives the make that wrote it, and it is read on its
# own: somebody opens obj/check-report to find out how last night went,
# a script greps it, a write-up quotes it.  So the question this test
# asks is not whether make noticed the failure -- it does, it exits
# nonzero and prints the failing test -- but what the file on disk says
# afterwards.  Before the fix it said whatever the last passing run had
# said, with that run's mtime, and there was no way for a reader to tell
# that from a report of the run they had just watched fail.
#
# Two suites, so that a report about one set of tests going red can be
# told apart from the project-wide one.  A test named without a suite
# would be put in every suite, which is exactly the distinction this
# needs to keep.
cat >Configfile <<EOF
LANGUAGES           += c
LANGUAGES           += bash

TEST_SUITES         += smoke

TEST_SUITES         += overnight

BINARIES            += suite
SOURCES             += suite.c
TESTSRC[smoke]      += loud.bash
TESTSRC[overnight]  += quiet.bash
EOF

cat >src/suite.c <<EOF
int main(void) { return 0; }
EOF

for t in loud quiet
do
    echo true > "test/suite/$t.bash"
done

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

##############################################################################
# A passing run writes the reports                                           #
##############################################################################
# The green state this test needs to start from: files on disk, saying
# so.  Everything below is about what happens to these four files.
make $MAKE_ARGS check
make $MAKE_ARGS report > green.out
cat green.out
grep -q "^NFAIL	0$" green.out

test -e obj/check-report
grep -q "^NFAIL	0$" obj/check-report

# The quiet report of a passing run is an empty file: ptest --quiet
# prints nothing when nothing failed.  That is why the quiet pair
# matters here at least as much as the loud one -- a stale green quiet
# report and a fresh one are the same zero bytes, so existence is the
# whole of what a reader has to go on.
test -e obj/check-report-quiet
test ! -s obj/check-report-quiet

make $MAKE_ARGS check-smoke
make $MAKE_ARGS report-smoke > green-smoke.out
cat green-smoke.out
grep -q "^NFAIL	0$" green-smoke.out
test -e obj/check-suite-smoke-report
test -e obj/check-suite-smoke-report-quiet

##############################################################################
# A failing run leaves no report at all                                      #
##############################################################################
# The sleep is for mtime granularity, which is a second on plenty of
# filesystems.
cat >test/suite/loud.bash <<'EOF'
exit 1
EOF
sleep 2s

if make $MAKE_ARGS report > red.out 2>&1
then
    exit 1
fi
cat red.out

# make said which test failed, on stdout, out of the recipe's own "cat
# $@.tmp".  That channel was never the broken one and this test would
# be watching the wrong thing if it only checked the file.
grep -q "FAIL	suite/loud.bash" red.out

# And the file that used to say NFAIL 0 is gone rather than stale.
test ! -e obj/check-report
test ! -e obj/check-report.tmp

##############################################################################
# Asking again still fails                                                   #
##############################################################################
# This is the guard on the shape of the fix rather than on the fix.
# Writing the report out and then exiting 1 would have made the file
# honest, and would also have made it newer than the stamp it came
# from -- so this second make would have had nothing to do and would
# have exited 0 with the tests still red.  Deleting keeps the report
# missing, which keeps it older than everything, which keeps make
# re-scoring and failing for as long as the tests are red.
if make $MAKE_ARGS report > red-again.out 2>&1
then
    exit 1
fi
cat red-again.out
grep -q "FAIL	suite/loud.bash" red-again.out
test ! -e obj/check-report

##############################################################################
# The quiet report goes the same way                                         #
##############################################################################
if make $MAKE_ARGS check > red-quiet.out 2>&1
then
    exit 1
fi
cat red-quiet.out
test ! -e obj/check-report-quiet
test ! -e obj/check-report-quiet.tmp

##############################################################################
# And so does a suite's pair                                                 #
##############################################################################
# The per-suite rules are the project-wide ones copied, so they are
# capable of going wrong on their own and are checked on their own.
if make $MAKE_ARGS report-smoke > red-smoke.out 2>&1
then
    exit 1
fi
cat red-smoke.out
grep -q "FAIL	suite/loud.bash" red-smoke.out
test ! -e obj/check-suite-smoke-report
test ! -e obj/check-suite-smoke-report.tmp

if make $MAKE_ARGS check-smoke > red-smoke-quiet.out 2>&1
then
    exit 1
fi
cat red-smoke-quiet.out
test ! -e obj/check-suite-smoke-report-quiet
test ! -e obj/check-suite-smoke-report-quiet.tmp

# The suite that stayed green keeps its reports, because a report is
# about the run it was made from and nothing else went red.
make $MAKE_ARGS check-overnight
make $MAKE_ARGS report-overnight > green-overnight.out
cat green-overnight.out
grep -q "^NFAIL	0$" green-overnight.out
test -e obj/check-suite-overnight-report
test -e obj/check-suite-overnight-report-quiet

##############################################################################
# Fixing the test brings the reports back                                    #
##############################################################################
# Deleting on failure is not a tree that can only lose reports: the
# next passing scoring writes one again, which is the other half of
# "the report exists if and only if the last scoring of it passed".
echo true > test/suite/loud.bash
sleep 2s

make $MAKE_ARGS check
make $MAKE_ARGS report > green-again.out
cat green-again.out
grep -q "^NFAIL	0$" green-again.out
test -e obj/check-report
grep -q "^NFAIL	0$" obj/check-report
test -e obj/check-report-quiet
test ! -s obj/check-report-quiet

make $MAKE_ARGS report-smoke > green-smoke-again.out
cat green-smoke-again.out
grep -q "^NFAIL	0$" green-smoke-again.out
test -e obj/check-suite-smoke-report

exit 0
