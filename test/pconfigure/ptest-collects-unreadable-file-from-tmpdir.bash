#include "harness_start.bash"

# What a test leaves in $PTEST_TMPDIR is what gets collected, and the
# manual says so without exceptions.  A file the test made unreadable
# -- a key fixture written 0600 and then 0000, a log a tool created
# with a restrictive umask -- is still something it left, and ptest is
# the owner of the directory: tar can't open the file, prints an error
# into the middle of make's output, and the result silently goes
# without it.

ptest="$(dirname "$PTEST_BINARY")/ptest"

mkdir -p check

cat >hides.sh <<'EOF'
#!/bin/bash
echo "the log" > "$PTEST_TMPDIR/log"
chmod 000 "$PTEST_TMPDIR/log"
mkdir "$PTEST_TMPDIR/sealed"
echo "inner" > "$PTEST_TMPDIR/sealed/file"
chmod 000 "$PTEST_TMPDIR/sealed"
exit 0
EOF
chmod +x hides.sh

"$ptest" --test hides.sh --out check/hides 2> ptest.err
cat ptest.err

tar -tf check/hides > members
cat members
grep -qx "log" members
grep -qx "sealed/file" members

# And collecting it said nothing alarming on the way.
test ! -s ptest.err

exit 0
