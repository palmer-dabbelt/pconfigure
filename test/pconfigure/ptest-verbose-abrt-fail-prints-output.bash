#include "harness_start.bash"

# The same question as a plain FAIL under --verbose, asked of the other
# way into NFAIL: a SIGABRT scored as a FAIL because the project said
# its asserts are failures.  It's the same verdict, so it gets the same
# treatment as an EROR's output, which is the test's own words rather
# than the archive they were collected into.

ptest="$(dirname "$PTEST_BINARY")/ptest"

mkdir -p check
cat >t.bash <<'EOF'
#!/bin/bash
echo "assertion failed: x == y"
kill -ABRT $$
EOF
chmod +x t.bash

"$ptest" --test t.bash --out check/t.bash
test "$(tar -xOf check/t.bash ptest__return)" = "134"

"$ptest" --verbose --no-check-make-check --abrt-is-fail-dir check > fail.out || true
cat -v fail.out
grep -a -q "FAIL	t.bash" fail.out
grep -a -q "^assertion failed: x == y$" fail.out

# Read the other way the same tarball is an EROR, and what --verbose
# prints for it is the comparison: the output and nothing else.
"$ptest" --verbose --no-check-make-check --check-dir check > eror.out || true
cat -v eror.out
grep -q "EROR	t.bash" eror.out

grep -a -v "FAIL\|EROR\|^N\|^$" fail.out > fail.body
grep -a -v "FAIL\|EROR\|^N\|^$" eror.out > eror.body
diff eror.body fail.body

exit 0
