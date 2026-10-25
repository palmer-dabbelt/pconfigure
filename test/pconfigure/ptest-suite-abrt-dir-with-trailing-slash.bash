#include "harness_start.bash"

# "--abrt-is-fail-dir DIR" scores a SIGABRT under DIR as a FAIL, and
# a directory is still the same directory with a slash after it --
# which is how a shell's tab completion hands one over.  A whole run
# already reads it that way.  A suite report has to find which
# directory each named result came from instead of walking down from
# the directory, and if that comparison is done on the text, "check/"
# owns nothing, so the same tarball is a FAIL in one report and an
# EROR in the other, and is labelled differently in each as well.

ptest="$(dirname "$PTEST_BINARY")/ptest"

mkdir -p check/t
cat >t.bash <<'EOF'
#!/bin/bash
kill -ABRT $$
EOF
chmod +x t.bash
"$ptest" --test t.bash --out check/t/aborts.bash
test "$(tar -xOf check/t/aborts.bash ptest__return)" = "134"

# The spelling without the slash, as the generated Makefile writes it:
# this is the answer both of the others have to match.
"$ptest" --no-check-make-check --abrt-is-fail-dir check \
    --check-suite s --check-result check/t/aborts.bash > plain.out || true
cat plain.out
grep -q "^\* FAIL	t/aborts.bash$" plain.out

"$ptest" --no-check-make-check --abrt-is-fail-dir check/ > whole.out || true
cat whole.out
grep -q "FAIL	" whole.out
grep -q "^NFAIL	1$" whole.out

"$ptest" --no-check-make-check --abrt-is-fail-dir check/ \
    --check-suite s --check-result check/t/aborts.bash > suite.out || true
cat suite.out
grep -q "^NFAIL	1$" suite.out
grep -q "^NEROR	0$" suite.out

diff plain.out suite.out
diff plain.out whole.out

exit 0
