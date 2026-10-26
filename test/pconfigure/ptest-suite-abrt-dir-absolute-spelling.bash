#include "harness_start.bash"

# The same directory named by its absolute path -- what a script that
# cds around before reporting naturally passes -- loses the
# --abrt-is-fail-dir it was given when the results are named
# relatively, so a SIGABRT that the project asked to have scored as a
# FAIL is an EROR.  A whole run walks down from the directory as it
# was spelled and never has the problem, so the two reports have to
# come out the same.

ptest="$(dirname "$PTEST_BINARY")/ptest"

mkdir -p check

printf '#!/bin/bash\nkill -ABRT $$\n' > ab.sh
chmod +x ab.sh
"$ptest" --test ab.sh --out check/ab

whole=0
"$ptest" --no-check-make-check --abrt-is-fail-dir "$PWD/check" \
    > whole.out || whole=$?
cat whole.out
test "$whole" = "1"
grep -q "^NFAIL	1$" whole.out

suite=0
"$ptest" --no-check-make-check --abrt-is-fail-dir "$PWD/check" \
    --check-suite s --check-result check/ab > suite.out || suite=$?
cat suite.out
test "$suite" = "1"
grep -q "^NFAIL	1$" suite.out
grep -q "^NEROR	0$" suite.out
diff whole.out suite.out

# And the other way round: the directory relative, the result absolute.
suite=0
"$ptest" --no-check-make-check --abrt-is-fail-dir check \
    --check-suite s --check-result "$PWD/check/ab" > suite2.out || suite=$?
cat suite2.out
test "$suite" = "1"
grep -q "^\* FAIL	ab$" suite2.out

exit 0
