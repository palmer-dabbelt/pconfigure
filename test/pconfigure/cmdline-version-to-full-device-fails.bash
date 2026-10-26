#include "harness_start.bash"

# --version that couldn't print its answer exited 0 anyway, so a
# script reading "pconfigure --version" into a variable can't tell an
# empty answer it got from one it never got.  cat, echo and every GNU
# tool answer a failed write to stdout with a non-zero exit, and say
# why on stderr.
test -w /dev/full || exit 0

status=0
$PTEST_BINARY --version > /dev/full 2> err.out || status=$?
cat err.out
test "$status" -ne 0

# Said on stderr, with the reason the system gave, since stdout is the
# thing that's broken.
grep -q "error: .*--version.*No space left on device" err.out
