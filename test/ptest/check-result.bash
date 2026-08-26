#include "harness_start.bash"

mkdir -p check sub/check

# A test result is a tarball of whatever the test left behind, with
# its exit status in "ptest__return" -- so this is the whole of what a
# report reads.
result() {
    rm -rf build
    mkdir build
    echo "$2" > build/ptest__return
    (cd build && tar -c ptest__return) > "$1"
}

result check/passes.bash 0
result check/fails.bash 1
result sub/check/elsewhere.bash 0

##############################################################################
# Everything that has been run                                               #
##############################################################################
# The report a build gets when nobody says otherwise, which is every
# result in every directory it was pointed at.  It fails, because one
# of the tests did.
if $PTEST_BINARY --no-check-make-check \
    --check-dir check --check-dir sub/check > all.out 2>&1
then
    exit 1
fi
cat all.out

grep -q "^NRUN	3$" all.out
grep -q "PASS	passes.bash" all.out
grep -q "FAIL	fails.bash" all.out
grep -q "PASS	sub/elsewhere.bash" all.out

##############################################################################
# One named set of them                                                      #
##############################################################################
# Which tests belong together is something the build knows and a
# directory of tarballs doesn't, so a suite is reported by being
# handed its results rather than by being described.
$PTEST_BINARY --no-check-make-check \
    --check-dir check --check-dir sub/check \
    --check-suite quick \
    --check-result check/passes.bash \
    --check-result sub/check/elsewhere.bash > quick.out 2>&1
cat quick.out

grep -q "^NRUN	2$" quick.out
grep -q "PASS	passes.bash" quick.out
grep -q "PASS	sub/elsewhere.bash" quick.out

# The result that wasn't named is not reported, and -- since it's the
# failing one -- its absence is what makes this run succeed.  A suite
# that reported on tests it never ran would fail for reasons that have
# nothing to do with the machine it ran on, which is the whole thing a
# suite exists to avoid.
if grep -q "fails.bash" quick.out
then
    exit 1
fi

# A test still knows which project it came from: the label is worked
# out from the check directory it lives under, the same way it is when
# the whole tree gets walked.
if grep -q "PASS	check/passes.bash" quick.out
then
    exit 1
fi

##############################################################################
# A named set with a failure in it                                           #
##############################################################################
# The other direction, so that the pass above is a pass rather than a
# report that never looks at what it read.
if $PTEST_BINARY --no-check-make-check \
    --check-dir check --check-dir sub/check \
    --check-suite slow \
    --check-result check/fails.bash > slow.out 2>&1
then
    exit 1
fi
cat slow.out

grep -q "^NRUN	1$" slow.out
grep -q "FAIL	fails.bash" slow.out

##############################################################################
# A set nobody joined                                                        #
##############################################################################
# A suite with no tests in it is a promise about what a name means,
# kept by a run with nothing to do.  Falling back to reporting
# everything would make an empty suite the loudest one in the build.
$PTEST_BINARY --no-check-make-check \
    --check-dir check --check-dir sub/check \
    --check-suite empty > empty.out 2>&1
cat empty.out

grep -q "No tests" empty.out
if grep -q "passes.bash" empty.out
then
    exit 1
fi

exit 0
