#include "harness_start.bash"

# A test that leaves a lot behind -- an unpacked tree, a cache, a
# directory of per-case logs -- still gets a result.  Collecting it by
# expanding every name in $PTEST_TMPDIR onto tar's command line puts a
# ceiling on that which nobody chose: past the kernel's argument limit
# tar is never started at all, the result comes out empty, and a test
# that passed is reported as an EROR.  Nested files would not have hit
# this; it is only the top level of the directory that gets expanded,
# which is why everything below is left at the top.

ptest="$(dirname "$PTEST_BINARY")/ptest"

mkdir -p check
cat >t.bash <<'EOF'
#!/bin/bash
cd "$PTEST_TMPDIR"
long="$(printf 'x%.0s' $(seq 1 180))"
seq 1 20000 | sed "s/^/$long-/" | xargs touch
echo "made them"
exit 0
EOF
chmod +x t.bash

"$ptest" --test t.bash --out check/t.bash || true

test "$(tar -xOf check/t.bash ptest__return)" = "0"
test "$(tar -tf check/t.bash | wc -l)" -ge 20000

"$ptest" --no-check-make-check --check-dir check > report.out || true
cat report.out
grep -q "^NPASS	1$" report.out

exit 0
