#include "harness_start.bash"

# A test's name in the report is the path of its result, and a path
# may hold a backslash -- a test named after the Windows path it
# exercises, say.  That result has to be found under the name it has,
# not under one with the backslashes read away, or a test that ran and
# failed is reported as one that never ran.  And the name is printed
# as written on every verdict line: read as an echo escape, a "\c"
# would end the FAIL line without its newline and glue the next test's
# verdict onto it, and a "\t" would split the name into a column of
# its own.

ptest="$(dirname "$PTEST_BINARY")/ptest"

mkdir -p check

cat >fails.sh <<'EOF'
#!/bin/bash
exit 1
EOF
cat >passes.sh <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x fails.sh passes.sh

"$ptest" --test fails.sh --out 'check/a-C:\cygwin\tmp'
"$ptest" --test passes.sh --out 'check/b-passes'

"$ptest" --no-check-make-check --check-dir check > report.out || true
cat -A report.out

grep -qxF -- '* FAIL	a-C:\cygwin\tmp' report.out
grep -qx "  PASS	b-passes" report.out
grep -qx "NFAIL	1" report.out
grep -qx "NPASS	1" report.out

exit 0
