#include "harness_start.bash"

# A ptest run by hand, with nothing to say about the binary, the
# source, the check directory or the scratch directory, hands the test
# an empty string for each -- not whatever directory it was started
# in, and not whatever the environment it was started from happened to
# carry.  The second half is not hypothetical: this very test runs
# under ptest, so every one of those variables is set to something real
# out here, and a ptest that only set the ones it was told about would
# leak them into a test that should have noticed it was given nothing.

ptest="$(dirname "$PTEST_BINARY")/ptest"

test -n "$PTEST_BINARY"
test -n "$PTEST_SRCDIR"
test -n "$PTEST_CHECKDIR"
test -n "$PTEST_SCRATCH_DIR"

mkdir -p check
cat >t.bash <<'EOF'
#!/bin/bash
echo "binary=[$PTEST_BINARY]"
echo "srcdir=[$PTEST_SRCDIR]"
echo "checkdir=[$PTEST_CHECKDIR]"
echo "scratch=[$PTEST_SCRATCH_DIR]"
exit 0
EOF
chmod +x t.bash

"$ptest" --test t.bash --out check/t
test "$(tar -xOf check/t ptest__return)" = "0"

tar -xOf check/t ptest__output > t.out
cat t.out
grep -q "^binary=\[\]$" t.out
grep -q "^srcdir=\[\]$" t.out
grep -q "^checkdir=\[\]$" t.out
grep -q "^scratch=\[\]$" t.out

# Nor is the scratch directory made anywhere just because a test might
# have wanted one.
test "$(ls -A)" = "$(printf 'check\nt.bash\nt.out')"

exit 0
