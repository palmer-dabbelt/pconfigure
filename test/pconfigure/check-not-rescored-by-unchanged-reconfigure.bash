#include "harness_start.bash"

# The other half of making "make check" notice that the set of tests it
# covers has changed: noticing only that.  What the stamps wait on is a
# file saying which results are in the set, and it is written only when
# that changes -- so a reconfigure that comes out the same, which is
# every Configfile edit that isn't about tests, leaves "make check" with
# nothing to do.  Waiting on the Makefile itself would have scored
# everything again after every one of them.
#
# And a scope file that has gone missing, which is somebody clearing out
# part of obj/ by hand, is a set nobody can vouch for: the next "make
# check" scores it again rather than stopping on a missing prerequisite.

mkdir -p src test/t

cat >Configfile <<'EOF'
LANGUAGES   += bash
TEST_SUITES += quick

BINARIES       += t
SOURCES        += t.bash
TESTSRC[quick] += passes.bash
EOF

cat >src/t.bash <<'EOF'
echo "Success"
EOF

cat >test/t/passes.bash <<'EOF'
exit 0
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS check
make $MAKE_ARGS check-quick

sleep 1
echo "# a comment, which changes nothing" >> Configfile
$PTEST_BINARY $PCONFIGURE_ARGS

make $MAKE_ARGS check > check.out 2>&1
cat check.out
grep -q "Nothing to be done for 'check'" check.out

make $MAKE_ARGS check-quick > check-quick.out 2>&1
cat check-quick.out
grep -q "Nothing to be done for 'check-quick'" check-quick.out

rm -f obj/check-all-scope obj/check-suite-quick-scope

make $MAKE_ARGS check > check-again.out 2>&1
cat check-again.out
if grep -q "Nothing to be done" check-again.out
then
    exit 1
fi

make $MAKE_ARGS check-quick > check-quick-again.out 2>&1
cat check-quick-again.out
if grep -q "Nothing to be done" check-quick-again.out
then
    exit 1
fi

exit 0
