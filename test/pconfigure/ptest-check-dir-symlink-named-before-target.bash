#include "harness_start.bash"

# A check directory reached through a symlink -- a build tree linked
# in from a bigger disk, say -- is still the same directory as the one
# it points at, and ptest counts it once however it is named.  Named
# through the link first and then by its target, the one that is kept
# is the link.  A walk that stops at a starting point that is a
# symlink then finds nothing under it, and the failing result drops
# out of the report without a word: NRUN 0 and an exit status of 0.
# The link named on its own has always done the same.

ptest="$(dirname "$PTEST_BINARY")/ptest"

mkdir -p real
ln -s real link

printf '#!/bin/bash\nexit 1\n' > fails.sh
chmod +x fails.sh
"$ptest" --test fails.sh --out real/fails

status=0
"$ptest" --no-check-make-check --check-dir link --check-dir real > both.out || status=$?
cat both.out
test "$status" = "1"
grep -q "^NRUN	1$" both.out
grep -q "^NFAIL	1$" both.out
grep -q "^\* FAIL	fails$" both.out

status=0
"$ptest" --no-check-make-check --check-dir link > link.out || status=$?
cat link.out
test "$status" = "1"
grep -q "^NRUN	1$" link.out
grep -q "^NFAIL	1$" link.out

exit 0
