#include "harness_start.bash"

# "make -n" prints what it would do and does nothing, and that is the
# whole of its contract: it is how somebody finds out what "make
# check" is about to cost before paying for it.  A test is the most
# expensive thing a build runs and the one most likely to have side
# effects outside the tree -- a VM booted, a network service poked --
# so it is the last thing a dry run may actually start.  Nor may a
# dry run write a result: a result is what tells the next real "make
# check" that the test is done.

mkdir -p src test/t

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES += t
SOURCES  += t.bash
TESTSRC  += side-effect.bash
EOF

cat >src/t.bash <<'EOF'
echo "Success"
EOF

cat >test/t/side-effect.bash <<'EOF'
echo "ran" >> "$PTEST_SRCDIR/ran.log"
exit 0
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS check
test "$(cat ran.log)" = "ran"
rm ran.log

# The program under test changed, so the result is out of date and a
# real "make check" would run the test again.  A dry one only says so.
sleep 1
cat >src/t.bash <<'EOF'
echo "Success, again"
EOF
make $MAKE_ARGS
cp check/t/side-effect.bash before.tar

make $MAKE_ARGS -n check > dry.out
cat dry.out
grep -q "ptest .*--test obj/check/t/side-effect.bash" dry.out

test ! -e ran.log
cmp before.tar check/t/side-effect.bash
test check/t/side-effect.bash -ot bin/t

# "make -q" is the same promise made more quietly: it answers whether
# anything is out of date, which it is, and does nothing about it.
if make $MAKE_ARGS -q check; then exit 1; fi
test ! -e ran.log
cmp before.tar check/t/side-effect.bash

# And the real one afterwards still knows there is work to do.
make $MAKE_ARGS check
test "$(cat ran.log)" = "ran"

exit 0
