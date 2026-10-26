#include "harness_start.bash"

# --abrt-is-fail-dir rescoring a SIGABRT as a FAIL for one directory's
# results has to work however that directory is spelled.  The trailing
# slash is taken care of; "./check" isn't.  A whole run walks the
# directory and finds the result under the name it was given, so it
# scores the abort as a FAIL -- but a suite report matches the result
# named with --check-result against the directory as text, "check/ab"
# is not under "./check", and the same abort is an EROR, under a label
# that has the check directory pasted into it.

ptest="$(dirname "$PTEST_BINARY")/ptest"

mkdir -p check

printf '#!/bin/bash\nkill -ABRT $$\n' > ab.sh
chmod +x ab.sh
"$ptest" --test ab.sh --out check/ab
test "$(tar -xOf check/ab ptest__return)" = "134"

whole=0
"$ptest" --no-check-make-check --abrt-is-fail-dir ./check > whole.out || whole=$?
cat whole.out
test "$whole" = "1"
grep -q "^\* FAIL	ab$" whole.out

suite=0
"$ptest" --no-check-make-check --abrt-is-fail-dir ./check \
    --check-suite s --check-result check/ab > suite.out || suite=$?
cat suite.out
test "$suite" = "1"
grep -q "^\* FAIL	ab$" suite.out

# And the other way round: the directory written plainly and the
# result written with the "./".
suite=0
"$ptest" --no-check-make-check --abrt-is-fail-dir check \
    --check-suite s --check-result ./check/ab > suite2.out || suite=$?
cat suite2.out
test "$suite" = "1"
grep -q "^\* FAIL	ab$" suite2.out

exit 0
