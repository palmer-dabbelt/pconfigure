#include "harness_start.bash"

# A file the test left behind is data, whatever it is called.  The
# names in $PTEST_TMPDIR are the test's to choose -- a tool under test
# that is handed a bad argument can easily leave a file named after
# it -- and handing them to tar as bare words lets a name that starts
# with a dash be read as one of tar's own options.  "-f" is the worst
# of those: it tells tar to write the archive into the next name on
# the line, which is the test's own captured output, so the result the
# report reads comes out empty and a test that passed is scored as an
# EROR nobody can explain.

ptest="$(dirname "$PTEST_BINARY")/ptest"

mkdir -p check
cat >t.bash <<'EOF'
#!/bin/bash
echo "all good"
echo "stray" > "$PTEST_TMPDIR/-f"
exit 0
EOF
chmod +x t.bash

"$ptest" --test t.bash --out check/t.bash || true

# The verdict and the output both survive ...
test "$(tar -xOf check/t.bash ptest__return)" = "0"
tar -xOf check/t.bash ptest__output | grep -q "^all good$"

# ... and so does the file itself, under its own name.
tar -tf check/t.bash | grep -qx -- "-f"

"$ptest" --no-check-make-check --check-dir check > report.out || true
cat report.out
grep -q "^NPASS	1$" report.out
grep -q "^NEROR	0$" report.out

exit 0
