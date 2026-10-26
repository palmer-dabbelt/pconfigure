#include "harness_start.bash"

# A check directory named alongside one of its own subdirectories --
# "check" for the whole project and "check/t" to make sure one
# target's results are in -- is two walks over the same tarballs, and
# the report counts every result under check/t twice.  A suite report
# already decides which directory a result belongs to by the longest
# one that holds it; a whole run has to land each result in that same
# one place, and that includes scoring a SIGABRT by whether the inner
# directory, not the outer one, asked for --abrt-is-fail-dir.

ptest="$(dirname "$PTEST_BINARY")/ptest"

mkdir -p check/t

printf '#!/bin/bash\nexit 0\n' > passes.sh
printf '#!/bin/bash\nkill -ABRT $$\n' > aborts.sh
chmod +x passes.sh aborts.sh
"$ptest" --test passes.sh --out check/t/passes
"$ptest" --test aborts.sh --out check/t/inner-aborts
"$ptest" --test aborts.sh --out check/outer-aborts

whole=0
"$ptest" --no-check-make-check --check-dir check --abrt-is-fail-dir check/t \
    > whole.out || whole=$?
cat whole.out
test "$whole" = "1"
grep -q "^NRUN	3$" whole.out
grep -q "^NPASS	1$" whole.out
grep -q "^NFAIL	1$" whole.out
grep -q "^NEROR	1$" whole.out
grep -q "^\* FAIL	check/inner-aborts$" whole.out
grep -q "^! EROR	outer-aborts$" whole.out

# The same three results named one at a time are the same report.
suite=0
"$ptest" --no-check-make-check --check-dir check --abrt-is-fail-dir check/t \
    --check-suite s --check-result check/outer-aborts \
    --check-result check/t/inner-aborts --check-result check/t/passes \
    > suite.out || suite=$?
cat suite.out
test "$suite" = "1"
diff <(sort whole.out) <(sort suite.out)

exit 0
