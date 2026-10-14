#include "harness_start.bash"

mkdir -p src test/test

# The flag on its own, called directly the way ptest-check-dirs.bash
# calls a bare ptest -- before anything about whether a Configfile can
# turn it on for a whole project is in the picture at all.

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

# Without the flag this is still an EROR -- the default the other
# test in this pair pins down didn't move just because this one
# exists.
"$ptest" --no-check-make-check > without.out || true
cat without.out
grep -q "EROR	test/aborts.bash" without.out
grep -q "^NEROR	1$" without.out

# With it, the same result tarball is read the other way.
"$ptest" --abrt-is-fail --no-check-make-check > with.out || true
cat with.out
grep -q "FAIL	test/aborts.bash" with.out
grep -q "^NFAIL	1$" with.out
grep -q "^NEROR	0$" with.out

exit 0
