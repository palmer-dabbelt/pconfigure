#include "harness_start.bash"

# A TESTSRC in a subdirectory of its own lands its result in that
# subdirectory of the target's check directory, but is handed the
# target's check directory itself as $PTEST_CHECKDIR -- the place
# every test of the target finds the others' results -- and a scratch
# directory that sits beside its own compiled self, outside the check
# directory, where it survives a re-run and isn't collected.

mkdir -p src test/t/nested

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += t
SOURCES   += t.bash
TESTSRC   += first.bash
TESTSRC   += nested/second.bash
DEPTESTS  += first.bash
EOF

echo 'echo t' > src/t.bash
cat >test/t/first.bash <<'EOF'
echo "from first" > "$PTEST_TMPDIR/note"
EOF
cat >test/t/nested/second.bash <<'EOF'
set -e
tar -xOf "$PTEST_CHECKDIR/first.bash" note > "$PTEST_TMPDIR/got"
echo "$PTEST_CHECKDIR" > "$PTEST_TMPDIR/checkdir"
echo "$PTEST_SCRATCH_DIR" > "$PTEST_TMPDIR/scratch"
test -d "$PTEST_SCRATCH_DIR"
date >> "$PTEST_SCRATCH_DIR/runs"
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS check

test "$(tar -xOf check/t/nested/second.bash ptest__return)" = "0"
test "$(tar -xOf check/t/nested/second.bash got)" = "from first"
test "$(tar -xOf check/t/nested/second.bash checkdir)" = "$PWD/check/t"
test "$(tar -xOf check/t/nested/second.bash scratch)" = "$PWD/obj/check/t/nested/second.bash.scratch"
test "$(wc -l < obj/check/t/nested/second.bash.scratch/runs | tr -d ' ')" = "1"

# Nothing of the scratch made it into the result.
if tar -tf check/t/nested/second.bash | grep -q runs
then
    exit 1
fi

# A re-run finds the scratch as it was left.
sleep 1
touch test/t/first.bash
make $MAKE_ARGS check
test "$(wc -l < obj/check/t/nested/second.bash.scratch/runs | tr -d ' ')" = "2"

make $MAKE_ARGS report > report.out
cat report.out
grep -q "^NPASS	2$" report.out

exit 0
