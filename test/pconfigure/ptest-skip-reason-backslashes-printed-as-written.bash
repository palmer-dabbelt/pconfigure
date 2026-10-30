#include "harness_start.bash"

# The reason a skipped test gave is reported beside its name so that
# nobody has to untar a result to read it, which only helps if what is
# printed is what the test said.  A reason with a backslash in it --
# a regular expression, a path, a quoted "\n" -- must not be run
# through escape processing on the way: a "\t" becomes a tab that
# splits the reason into another column of a tab-separated report, and
# a "\n" makes a second line that is no test's at all.

ptest="$(dirname "$PTEST_BINARY")/ptest"

mkdir -p check

cat >skips.sh <<'EOF'
#!/bin/bash
echo 'SKIP: needs grep -P for \t and \n in patterns'
exit 0
EOF
chmod +x skips.sh

"$ptest" --test skips.sh --out check/skips

"$ptest" --no-check-make-check --check-dir check > report.out
cat -ev report.out

grep -qF -- '- SKIP	skips	needs grep -P for \t and \n in patterns' report.out

# One line per test, then the blank line and the five counts.
test "$(wc -l < report.out | tr -d ' ')" = "7"

exit 0
