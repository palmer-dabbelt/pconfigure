#include "harness_start.bash"

# make bunches its single-letter modes together at the front of
# $MAKEFLAGS, so "make -s -n check" hands ptest "ns" rather than "n",
# and "make -kn" hands it "kn".  Either is a dry run and the test must
# not start, nor may the out-of-date result be rewritten.
#
# The ptest recipe carries a '+', so make runs it even under -n: what
# keeps the test from starting is ptest finding the "n" for itself.
# That only means something if there is a compiled test it could
# start, so the test is built and run for real first and then made
# stale by changing the program it tests.

mkdir -p src test/t

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += t
SOURCES   += t.bash
TESTSRC   += side-effect.bash
EOF

cat >src/t.bash <<'EOF'
echo one
EOF

cat >test/t/side-effect.bash <<'EOF'
echo ran >> "$PTEST_SRCDIR/ran.log"
exit 0
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS check
test "$(cat ran.log)" = "ran"
rm ran.log

sleep 1
cat >src/t.bash <<'EOF'
echo two
EOF
make $MAKE_ARGS
cp check/t/side-effect.bash before.tar

for flags in "-s -n" "-sn" "-k -n" "-kn" "-i -n"
do
    make $MAKE_ARGS $flags check > dry.out
    cat dry.out
    test ! -e ran.log
    cmp before.tar check/t/side-effect.bash
    test check/t/side-effect.bash -ot bin/t
done

# And letters that aren't a dry run don't stop the test: -k, -i and
# -s together still run it.
make $MAKE_ARGS -k -i -s check
test "$(cat ran.log)" = "ran"
test bin/t -ot check/t/side-effect.bash

exit 0
