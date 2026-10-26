#include "harness_start.bash"

# The same as --version: --help whose text never made it out has not
# done what it was asked, and exiting 0 says it has.
test -w /dev/full || exit 0

status=0
$PTEST_BINARY --help > /dev/full 2> err.out || status=$?
cat err.out
test "$status" -ne 0
grep -q "error: .*--help.*No space left on device" err.out
