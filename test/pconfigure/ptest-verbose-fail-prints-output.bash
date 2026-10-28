#include "harness_start.bash"

# "ptest --verbose" is what somebody runs to see why a test went wrong,
# and what they want to see is what the test printed.  An EROR shows
# exactly that.  A FAIL is the more common of the two and deserves the
# same: dumping the result tarball itself instead puts tar headers,
# every other file the test left behind and a few kilobytes of NUL
# padding on the terminal, with the output somewhere in the middle.
# This tree's own harness calls "ptest --verbose" at the end of every
# test, so that noise is in every failing test's log here too.

ptest="$(dirname "$PTEST_BINARY")/ptest"

mkdir -p check
cat >t.bash <<'EOF'
#!/bin/bash
echo "expected 4, got 5"
echo "not output" > "$PTEST_TMPDIR/leftover"
exit 1
EOF
chmod +x t.bash

"$ptest" --test t.bash --out check/t.bash

"$ptest" --verbose --no-check-make-check --check-dir check > report.out || true
cat -v report.out

grep -a -q "FAIL	t.bash" report.out
grep -a -q "^expected 4, got 5$" report.out

# Text, and only the output: no tar member names, no other files'
# contents, no NULs.
test "$(tr -d -c '\000' < report.out | wc -c | tr -d ' ')" = "0"
if grep -a -q "ptest__return\|leftover\|not output" report.out
then
    exit 1
fi

exit 0
