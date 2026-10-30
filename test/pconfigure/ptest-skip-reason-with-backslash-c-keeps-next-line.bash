#include "harness_start.bash"

# A skip's reason is whatever the test printed after "SKIP:", and a
# reason that names a Windows path is an ordinary thing for a test
# that needs a cross toolchain to print.  The report puts it on the
# line that names the test, so it has to come out as text: read as
# echo escapes, the "\c" in "C:\cygwin" ends the output right there,
# newline and all, and the next test's line is glued onto the end of
# this one -- so a report that is grepped for "^  PASS" loses a pass.

ptest="$(dirname "$PTEST_BINARY")/ptest"

mkdir -p check

cat >a-skips.sh <<'EOF'
#!/bin/bash
echo 'SKIP: no compiler at C:\cygwin\bin\gcc'
exit 0
EOF
cat >b-passes.sh <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x a-skips.sh b-passes.sh

"$ptest" --test a-skips.sh --out check/a-skips
"$ptest" --test b-passes.sh --out check/b-passes

"$ptest" --no-check-make-check --check-dir check > report.out
cat -ev report.out

# The pass is a line of its own ...
grep -q "^  PASS	b-passes$" report.out

# ... and the skip line carries the reason as it was written.
grep -qF -- '- SKIP	a-skips	no compiler at C:\cygwin\bin\gcc' report.out

grep -q "^NSKIP	1$" report.out
grep -q "^NPASS	1$" report.out

exit 0
