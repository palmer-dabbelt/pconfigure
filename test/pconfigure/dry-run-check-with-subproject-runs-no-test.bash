#include "harness_start.bash"

# "make -n check" from the top of a tree with a subproject: the
# subproject's check rules come from its own Makefile fragment, which
# the top one includes, and are written with the subproject's path
# variable in front of every name.  Its tests must stay printed and not
# run, the same as the top's own, and "make -n" from inside a
# subproject configured on its own must do the same.
#
# The ptest recipe carries a '+', so make runs it even under -n, and
# it is ptest that has to notice the dry run.  So every test here has
# been built and run once and then made stale by changing the program
# it tests: a ptest that missed the dry run would find a compiled test
# to start, rather than failing for want of one.

mkdir -p src test/top sub/src sub/test/s

cat >Configfile <<'EOF'
LANGUAGES   += bash

SUBPROJECTS += sub

BINARIES    += top
SOURCES     += top.bash
TESTSRC     += top-ran.bash
EOF

cat >sub/Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += s
SOURCES   += s.bash
TESTSRC   += sub-ran.bash
EOF

cat >src/top.bash <<'EOF'
echo top
EOF

cat >sub/src/s.bash <<'EOF'
echo s
EOF

cat >test/top/top-ran.bash <<'EOF'
echo ran >> "$PTEST_SRCDIR/top-ran.log"
EOF

cat >sub/test/s/sub-ran.bash <<'EOF'
echo ran >> "$PTEST_SRCDIR/sub-ran.log"
EOF

# Builds and runs both tests, then changes both programs so that both
# results are out of date and a real "make check" would run them again.
stale_both() {
    make $MAKE_ARGS check
    test "$(cat top-ran.log)" = "ran"
    test "$(cat sub/sub-ran.log)" = "ran"
    rm top-ran.log sub/sub-ran.log

    sleep 1
    echo "echo top again" >> src/top.bash
    echo "echo s again" >> sub/src/s.bash
    make $MAKE_ARGS
    cp check/top/top-ran.bash top-before.tar
    cp sub/check/s/sub-ran.bash sub-before.tar
}

# Neither test ran and neither result was rewritten.
neither_ran() {
    test ! -e top-ran.log
    test ! -e sub/sub-ran.log
    cmp top-before.tar check/top/top-ran.bash
    cmp sub-before.tar sub/check/s/sub-ran.bash
}

$PTEST_BINARY $PCONFIGURE_ARGS
stale_both

make $MAKE_ARGS -n check > dry.out
cat dry.out
# The recipe spells ptest's path as one quoted shell word, so the
# closing quote may sit between the name and its first argument.
grep -q "ptest'\? .*--out check/top/top-ran.bash" dry.out
grep -q "ptest'\? .*--out sub/check/s/sub-ran.bash" dry.out
neither_ran

# The same from inside the subproject, configured on its own.  Its
# own Makefile has the subproject's rules without the top's prefix,
# so its test is stale here too: the program changed above and the
# result is still the one from before.
(cd sub && $PTEST_BINARY $PCONFIGURE_ARGS)
make $MAKE_ARGS -C sub
make $MAKE_ARGS -C sub -n check > dry.out
cat dry.out
grep -q "ptest'\? .*--out check/s/sub-ran.bash" dry.out
neither_ran

# And the real thing runs both.
make $MAKE_ARGS check
test "$(cat top-ran.log)" = "ran"
test "$(cat sub/sub-ran.log)" = "ran"

exit 0
