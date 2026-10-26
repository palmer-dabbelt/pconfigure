#include "harness_start.bash"

mkdir -p check

# A test result is a tarball of whatever the test left behind, with
# its exit status in "ptest__return".
result() {
    rm -rf build
    mkdir build
    echo "$2" > build/ptest__return
    (cd build && tar -c ptest__return) > "$1"
}

result check/passes.bash 0
result check/also-passes.bash 0
result check/fails.bash 1

##############################################################################
# The set, read from a file                                                  #
##############################################################################
# A Makefile hands the results over in its check scope, which lists
# them one to a line ahead of an empty one and has things for make
# after that -- among them names that are results too, which are not
# being asked about.
cat > scope <<'EOS'
check/passes.bash
check/also-passes.bash

ptest --check-dir check --check-suite quick
check/fails.bash
EOS

$PTEST_BINARY --no-check-make-check --check-dir check \
    --check-suite quick --check-results-from scope > quick.out 2>&1
cat quick.out

grep -q "^NRUN	2$" quick.out
grep -q "PASS	passes.bash" quick.out
grep -q "PASS	also-passes.bash" quick.out
if grep -q "fails.bash" quick.out
then
    exit 1
fi

##############################################################################
# A file with no empty line, and no newline at the end                       #
##############################################################################
printf 'check/passes.bash\ncheck/fails.bash' > list

if $PTEST_BINARY --no-check-make-check --check-dir check \
    --check-named --check-results-from list > list.out 2>&1
then
    exit 1
fi
cat list.out

grep -q "^NRUN	2$" list.out
grep -q "FAIL	fails.bash" list.out

##############################################################################
# A file with nothing in it                                                  #
##############################################################################
# The same as a suite nobody joined: no tests, rather than every
# result on disk.
printf '\nptest --check-dir check --check-named\n' > none
$PTEST_BINARY --no-check-make-check --check-dir check \
    --check-named --check-results-from none > none.out 2>&1
cat none.out
grep -q "No tests" none.out

##############################################################################
# A file that isn't there                                                    #
##############################################################################
# Is a report that can't be made, not one about nothing.
if $PTEST_BINARY --no-check-make-check --check-dir check \
    --check-named --check-results-from missing > missing.out 2>&1
then
    exit 1
fi
cat missing.out
if grep -q "No tests" missing.out
then
    exit 1
fi

exit 0
