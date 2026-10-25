#include "harness_start.bash"

mkdir -p src test/test sub/src sub/test/helper

# ABRT_IS_FAIL belongs to the project that said it, and that has to
# survive the project's results being reported from above: a parent's
# "make report" is one ptest run over every project's check directory,
# so a flag that only went onto the subproject's own Makefile never
# reached the report anybody actually reads.  The other half is that
# the parent never asked, so its own abort stays an EROR.

ptest="$(dirname "$PTEST_BINARY")/ptest"

cat >Configfile <<'EOF'
SUBPROJECTS += sub

LANGUAGES += bash

BINARIES += test
SOURCES  += test.bash
TESTSRC  += aborts.bash
EOF

cat >src/test.bash <<'EOF'
echo "Success"
EOF

cat >test/test/aborts.bash <<'EOF'
kill -ABRT $$
EOF

cat >sub/Configfile <<'EOF'
ABRT_IS_FAIL = true

LANGUAGES += bash

LIBEXECS += helper
SOURCES  += helper.bash
TESTSRC  += aborts.bash
TESTSRC  += passes.bash
EOF

cat >sub/src/helper.bash <<'EOF'
echo "Success"
EOF

cat >sub/test/helper/aborts.bash <<'EOF'
kill -ABRT $$
EOF

cat >sub/test/helper/passes.bash <<'EOF'
exit 0
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# Said per directory, and only for the one that asked.
grep -q "ptest' .*--check-dir check --abrt-is-fail-dir sub/check" Makefile
if grep -q -- "--abrt-is-fail " Makefile
then
    exit 1
fi

printf 'check\nsub/check\tabrt-is-fail\n' >expected
diff expected obj/check-dirs

if make $MAKE_ARGS check > check.out 2>&1
then
    exit 1
fi
cat check.out

test "$(tar -xOf check/test/aborts.bash ptest__return)" = "134"
test "$(tar -xOf sub/check/helper/aborts.bash ptest__return)" = "134"

check_report() {
    cat "$1"
    grep -q "EROR	test/aborts.bash" "$1"
    grep -q "FAIL	.*helper/aborts.bash" "$1"
    grep -q "PASS	.*helper/passes.bash" "$1"
    grep -q "^NFAIL	1$" "$1"
    grep -q "^NEROR	1$" "$1"
}

if make $MAKE_ARGS report > report.out 2>&1
then
    exit 1
fi
check_report report.out

# A bare ptest reads the same answer out of obj/check-dirs.
"$ptest" --no-check-make-check > bare.out 2>&1 || true
check_report bare.out

exit 0
