#include "harness_start.bash"

# Which tests a suite holds is said by the Configfile, so it changes
# when the Configfile does -- and a "make check-<suite>" after that
# has to be about the suite as it now is.  Here a test that is known
# to fail moves into a suite that passed a moment ago.  Its result is
# already on disk and older than the suite's stamp, so nothing about
# the files alone says anything is out of date; but "make report" for
# the same suite reads it and fails, and "make check" saying "nothing
# to be done" beside that is two answers to one question.

mkdir -p src test/t

cat >Configfile <<'EOF'
LANGUAGES   += bash
TEST_SUITES += quick
TEST_SUITES += slow

BINARIES       += t
SOURCES        += t.bash
TESTSRC[quick] += passes.bash
TESTSRC[slow]  += fails.bash
EOF

cat >src/t.bash <<'EOF'
echo "Success"
EOF

cat >test/t/passes.bash <<'EOF'
exit 0
EOF

cat >test/t/fails.bash <<'EOF'
exit 1
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

if make $MAKE_ARGS check-slow
then
    exit 1
fi
sleep 1
make $MAKE_ARGS check-quick

sleep 1
sed -i.bak 's/^TESTSRC\[slow\]  += fails.bash$/TESTSRC[quick] += fails.bash/' Configfile
grep -q "TESTSRC\[quick\] += fails.bash" Configfile
$PTEST_BINARY $PCONFIGURE_ARGS

# The two have to agree, and the report is the one that's right.
if make $MAKE_ARGS report-quick > report.out
then
    exit 1
fi
cat report.out
grep -q "FAIL	t/fails.bash" report.out

if make $MAKE_ARGS check-quick > check.out 2>&1
then
    cat check.out
    exit 1
fi
cat check.out
grep -q "FAIL	t/fails.bash" check.out

exit 0
