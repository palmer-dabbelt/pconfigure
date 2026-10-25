#include "harness_start.bash"

# A test that finished has finished, whatever it left behind.  Plenty
# of real tools leave a directory that can't be written to -- Go's
# module cache, a git object store, a fixture unpacked from a tarball
# that recorded its modes -- and the test has no reason to know that
# cleaning up its $PTEST_TMPDIR is going to be somebody's problem.
# When ptest's own "rm -rf" can't remove it, that failure must not
# become the check target's: the result is written, so make has to
# see a test that ran, carry on to the report, and leave nothing
# behind in the system temp.

mkdir -p src test/t

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES += t
SOURCES  += t.bash
TESTSRC  += readonly.bash
TESTSRC  += plain.bash
EOF

cat >src/t.bash <<'EOF'
echo "Success"
EOF

cat >test/t/readonly.bash <<'EOF'
mkdir -p "$PTEST_TMPDIR/cache/mod"
echo "data" > "$PTEST_TMPDIR/cache/mod/file"
chmod -R a-w "$PTEST_TMPDIR/cache"
echo "$PTEST_TMPDIR" > "$PTEST_SCRATCH_DIR/where"
exit 0
EOF

cat >test/t/plain.bash <<'EOF'
exit 0
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

make $MAKE_ARGS check > check.out 2>&1 || status=$?
cat check.out
where="$(cat obj/check/t/readonly.bash.scratch/where)"
if test -d "$where"
then
    chmod -R u+w "$where"
    rm -rf "$where"
    exit 1
fi
test "${status-0}" = "0"

# The fixture is in the result like anything else the test left.
test "$(tar -xOf check/t/readonly.bash cache/mod/file)" = "data"
test "$(tar -xOf check/t/readonly.bash ptest__return)" = "0"

make $MAKE_ARGS report > report.out
cat report.out
grep -q "^NPASS	2$" report.out

exit 0
