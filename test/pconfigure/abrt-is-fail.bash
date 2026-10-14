#include "harness_start.bash"

mkdir -p src test/test

# ABRT_IS_FAIL is the opt-in half of the pair with
# abrt-is-eror-by-default.bash: a project whose tests fail by calling
# a libc assert() has every one of those failures looking exactly
# like a crash ptest can't otherwise tell from a harness error, so
# this bakes "--abrt-is-fail" onto the project's own "make
# check"/"make report" recipes and asks ptest to call exit 134
# (128+SIGABRT) a FAIL instead.

cat >Configfile <<'EOF'
ABRT_IS_FAIL = true

LANGUAGES += bash

BINARIES += test
SOURCES += test.bash
TESTSRC += aborts.bash
TESTSRC += passes.bash
EOF

cat >src/test.bash <<'EOF'
echo "Success"
EOF

cat >test/test/aborts.bash <<'EOF'
kill -ABRT $$
EOF

cat >test/test/passes.bash <<'EOF'
exit 0
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# "make check" and "make report" are the ones ABRT_IS_FAIL actually
# reaches -- they're what runs the baked-in ptest command line, not a
# bare ptest typed by hand, which is why this doesn't just call
# "$ptest" --abrt-is-fail the way the other test calls plain ptest.
if make $MAKE_ARGS check > check.out 2>&1
then
    exit 1
fi
cat check.out

test "$(tar -xOf check/test/aborts.bash ptest__return)" = "134"

if make $MAKE_ARGS report > report.out 2>&1
then
    exit 1
fi
cat report.out
grep -q "FAIL	test/aborts.bash" report.out
grep -q "PASS	test/passes.bash" report.out
grep -q "^NFAIL	1$" report.out
grep -q "^NEROR	0$" report.out

exit 0
