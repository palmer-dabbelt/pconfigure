#include "harness_start.bash"

# pgcc-config refuses a test that comes without a flag, but that
# refusal must only catch arguments past the version: called with just
# a program and a version it still goes looking for a patch release of
# that version on the PATH and prints the newest one it finds.
gcc_config="$(dirname "$PTEST_BINARY")/pgcc-config"
test -x "$gcc_config"

mkdir fakebin
for x in 1 3
do
    printf '#!/bin/bash\nexit 0\n' >fakebin/fakecc-4.5.$x
    chmod +x fakebin/fakecc-4.5.$x
done
export PATH="$(pwd)/fakebin:$PATH"

"$gcc_config" fakecc 4.5 >search.out 2>search.err
cat search.out search.err

test "$(cat search.out)" == "fakecc-4.5.3"
test ! -s search.err
