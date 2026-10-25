#include "harness_start.bash"

# $PTEST_TMPDIR is a directory of the test's own, empty when it starts
# and gone when it finishes, and everything left in it -- directories
# and all -- lands in the result.  "Empty when it starts" is the half a
# rerun leans on: a test that found its previous run's files would
# pass the second time for reasons that have nothing to do with the
# tree.  "Gone when it finishes" is what keeps a long suite from
# filling the system temp, and a test that was handed the same path
# twice would be reading the first run's leftovers.

ptest="$(dirname "$PTEST_BINARY")/ptest"

mkdir -p check
cat >t.bash <<'EOF'
#!/bin/bash
found="$(ls -A "$PTEST_TMPDIR")"
echo "$found" > "$PTEST_TMPDIR/found"
echo "$PTEST_TMPDIR" > "$PTEST_TMPDIR/where"
mkdir -p "$PTEST_TMPDIR/deep/er"
echo "kept" > "$PTEST_TMPDIR/deep/er/file"
exit 0
EOF
chmod +x t.bash

"$ptest" --test t.bash --out check/first
"$ptest" --test t.bash --out check/second

for run in first second
do
    # Nothing there but the capture ptest itself opened.
    test "$(tar -xOf check/$run found)" = "ptest__output"
    test "$(tar -xOf check/$run deep/er/file)" = "kept"
    test ! -e "$(tar -xOf check/$run where)"
done

test "$(tar -xOf check/first where)" != "$(tar -xOf check/second where)"

exit 0
