#include "harness_start.bash"

# A suite report finds which check directory a named result belongs
# to by picking the longest directory that the result's path starts
# with -- and the length it has to beat starts out as that of ".", the
# answer for a result under none of them.  So a directory whose name
# is one character long never wins, and a project that keeps its
# results in "t" and asked for --abrt-is-fail-dir t gets its asserts
# scored as EROR in the suite report and as FAIL in the whole one.

ptest="$(dirname "$PTEST_BINARY")/ptest"

mkdir -p t/x
cat >t.bash <<'EOF'
#!/bin/bash
kill -ABRT $$
EOF
chmod +x t.bash
"$ptest" --test t.bash --out t/x/aborts.bash
test "$(tar -xOf t/x/aborts.bash ptest__return)" = "134"

"$ptest" --no-check-make-check --abrt-is-fail-dir t > whole.out || true
cat whole.out
grep -q "^\* FAIL	x/aborts.bash$" whole.out

"$ptest" --no-check-make-check --abrt-is-fail-dir t \
    --check-suite s --check-result t/x/aborts.bash > suite.out || true
cat suite.out
grep -q "^\* FAIL	x/aborts.bash$" suite.out
grep -q "^NEROR	0$" suite.out

# A two-character name is the control: the same tarball, the same
# flags, one letter longer.
mkdir -p tt/x
cp t/x/aborts.bash tt/x/aborts.bash
"$ptest" --no-check-make-check --abrt-is-fail-dir tt \
    --check-suite s --check-result tt/x/aborts.bash > control.out || true
cat control.out
grep -q "^\* FAIL	x/aborts.bash$" control.out

exit 0
