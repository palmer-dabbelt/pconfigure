#include "harness_start.bash"

# --check-dir "may be given more than once", which is how a report by
# hand covers several projects.  Naming the same directory twice --
# a shell history edited in place, a wrapper that adds the default
# on top of what it was given -- walks it twice, so every result is
# counted twice and a single failure reads as NFAIL 2.  The slashes are
# already stripped so that every spelling is the same text; the same
# text twice is still one directory.

ptest="$(dirname "$PTEST_BINARY")/ptest"

mkdir -p check

printf '#!/bin/bash\nexit 1\n' > fails.sh
chmod +x fails.sh
"$ptest" --test fails.sh --out check/fails

status=0
"$ptest" --no-check-make-check --check-dir check --check-dir check/ > report.out || status=$?
cat report.out
test "$status" = "1"
grep -q "^NRUN	1$" report.out
grep -q "^NFAIL	1$" report.out
test "$(grep -c "FAIL	fails" report.out)" = "1"

exit 0
