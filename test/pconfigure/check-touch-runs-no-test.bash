#include "harness_start.bash"

# "make -t" marks what is out of date as up to date by touching it,
# instead of running the recipes that would have made it.  Somebody
# reaching for it on "make check" wants the tests considered done
# without running them -- after a change they know can't matter, say
# -- and a test that runs anyway is the one thing they asked not to
# happen.

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
rm ran.log

sleep 1
cat >src/t.bash <<'EOF'
echo "Success, again"
EOF
make $MAKE_ARGS
cp check/t/side-effect.bash before.tar

make $MAKE_ARGS -t check > touch.out
cat touch.out
grep -q "touch check/t/side-effect.bash" touch.out

# Touched is all: the old verdict is still the one in the tarball, now
# newer than the program, so the next real "make check" has nothing to
# do for it.
test ! -e ran.log
cmp before.tar check/t/side-effect.bash
test check/t/side-effect.bash -nt bin/t

make $MAKE_ARGS check
test ! -e ran.log

exit 0
