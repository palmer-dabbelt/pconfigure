#include "harness_start.bash"

# What a test leaves in $PTEST_TMPDIR is what gets collected, and the
# manual says so without exceptions.  A file whose name starts with a
# dot is still something the test left there: a test that runs "git
# init" leaves a .git, one that points $HOME at its scratch leaves a
# .cache, and the log a test writes to explain a failure is as likely
# to be called ".log" as anything else.  Losing those silently means
# the one result somebody opens to find out what went wrong is missing
# the thing they went looking for.

ptest="$(dirname "$PTEST_BINARY")/ptest"

mkdir -p check
cat >t.bash <<'EOF'
#!/bin/bash
echo "visible" > "$PTEST_TMPDIR/log"
echo "hidden" > "$PTEST_TMPDIR/.log"
mkdir "$PTEST_TMPDIR/.state"
echo "nested" > "$PTEST_TMPDIR/.state/data"
exit 0
EOF
chmod +x t.bash

"$ptest" --test t.bash --out check/t.bash
tar -tf check/t.bash | tee members

# The ordinary file is there, which is what makes the two below about
# the dot rather than about collection not working at all.
test "$(tar -xOf check/t.bash log)" = "visible"

test "$(tar -xOf check/t.bash .log)" = "hidden"
test "$(tar -xOf check/t.bash .state/data)" = "nested"

exit 0
