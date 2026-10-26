#include "harness_start.bash"

# A test of a program's behaviour on a directory it can't write to
# reaches for the one directory it owns: "chmod a-w $PTEST_TMPDIR",
# then run the program and check that it refused.  ptest writes the
# test's exit status into that same directory afterwards, so the
# status can't be written, the result has no ptest__return, and a
# test that passed is scored as an EROR.  ptest already takes its
# permissions back before removing the directory; collecting it needs
# the same.

ptest="$(dirname "$PTEST_BINARY")/ptest"

mkdir -p check

cat >locks.sh <<'EOF'
#!/bin/bash
echo "checked" > "$PTEST_TMPDIR/log"
chmod a-w "$PTEST_TMPDIR"
if touch "$PTEST_TMPDIR/should-not-exist" 2>/dev/null
then
    exit 1
fi
exit 0
EOF
chmod +x locks.sh

"$ptest" --test locks.sh --out check/locks

test "$(tar -xOf check/locks ptest__return)" = "0"
test "$(tar -xOf check/locks log)" = "checked"

"$ptest" --no-check-make-check --check-dir check > report.out
cat report.out
grep -q "^  PASS	locks$" report.out
grep -q "^NEROR	0$" report.out

exit 0
