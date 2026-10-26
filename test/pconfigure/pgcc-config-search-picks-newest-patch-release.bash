#include "harness_start.bash"

# Without a test and a flag, pgcc-config looks for a compiler of the
# given version by its patch-release name, "<program>-<version>.<x>",
# and answers with the newest one it finds on the PATH -- which is
# what a COMPILER line wants when several point releases of one
# compiler are installed side by side.  An older patch release beside
# it, or a different minor version, mustn't be picked instead.
gcc_config="$(dirname "$PTEST_BINARY")/pgcc-config"
test -x "$gcc_config"

mkdir fakebin
for name in fakecc-4.8.2 fakecc-4.8.7 fakecc-4.9.9
do
    printf '#!/bin/sh\nexit 0\n' >fakebin/$name
    chmod +x fakebin/$name
done
export PATH="$(pwd)/fakebin:$PATH"

test "$("$gcc_config" fakecc 4.8)" = "fakecc-4.8.7"
test "$("$gcc_config" fakecc 4.9)" = "fakecc-4.9.9"

exit 0
