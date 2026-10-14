#include "harness_start.bash"

mkdir -p src test/test

# ptest's classification is PASS (exit 0), FAIL (exit 1), or EROR
# (anything else) -- and "anything else" deliberately includes a
# test that was killed by a signal, exit 134 for abort() included.
# EROR means the harness doesn't know whether the test found a bug:
# a crash can just as easily mean it never finished running the test
# at all, same as a missing binary or an unreadable result would.
# Only the test itself knows which failure modes are "the test ran
# fine and found one" and which aren't, so turning every crash into a
# FAIL by default would quietly hide the distinction a FAIL is
# supposed to draw: see abrt-is-fail.bash for the opt-in that gets
# this projects that are willing to make that call for themselves.

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES += test
SOURCES += test.bash
TESTSRC += aborts.bash
EOF

cat >src/test.bash <<'EOF'
echo "Success"
EOF

cat >test/test/aborts.bash <<'EOF'
kill -ABRT $$
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

if make $MAKE_ARGS check > check.out 2>&1
then
    exit 1
fi
cat check.out

test "$(tar -xOf check/test/aborts.bash ptest__return)" = "134"

ptest="$(dirname "$PTEST_BINARY")/ptest"
"$ptest" --no-check-make-check > report.out || true
cat report.out
grep -q "EROR	test/aborts.bash" report.out
grep -q "^NFAIL	0$" report.out
grep -q "^NEROR	1$" report.out

exit 0
