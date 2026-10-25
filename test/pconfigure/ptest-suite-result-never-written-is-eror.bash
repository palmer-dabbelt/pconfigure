#include "harness_start.bash"

# A suite report is handed its results by name, so one of them can be
# a name with nothing behind it -- a test whose run was interrupted, a
# result somebody cleared by hand.  That is the harness not getting an
# answer out of the test, which is what EROR means; it is counted in
# NRUN like any other result, and it is not quietly left out of a
# report that would then pass.

ptest="$(dirname "$PTEST_BINARY")/ptest"

mkdir -p check/t
cat >t.bash <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x t.bash
"$ptest" --test t.bash --out check/t/there.bash

status=0
"$ptest" --no-check-make-check --check-dir check --check-suite s \
    --check-result check/t/there.bash \
    --check-result check/t/gone.bash > report.out 2>/dev/null || status=$?
cat report.out
test "$status" = "2"
grep -q "PASS	t/there.bash" report.out
grep -q "EROR	t/gone.bash" report.out
grep -q "^NRUN	2$" report.out
grep -q "^NEROR	1$" report.out

exit 0
