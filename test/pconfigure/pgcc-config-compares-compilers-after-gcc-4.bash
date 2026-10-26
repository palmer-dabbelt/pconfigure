#include "harness_start.bash"

# pgcc-config used to refuse every compiler whose major version wasn't
# 4, because its comparison needed "sort -V" for anything else and OSX
# doesn't have one.  That's every GCC since 2015.  Comparing in bash
# arithmetic has no such limit, so a GCC 13 -- which prints just "13"
# for -dumpversion -- is newer than 4.5 and older than 14, and the
# same release as 13.0.
gcc_config="$(dirname "$PTEST_BINARY")/pgcc-config"
test -x "$gcc_config"

mkdir fakebin
cat >fakebin/gcc13 <<'EOF2'
#!/bin/bash
if [[ "$1" == "-dumpversion" ]]
then
    echo 13
    exit 0
fi
exit 1
EOF2
chmod +x fakebin/gcc13
export PATH="$(pwd)/fakebin:$PATH"

test "$("$gcc_config" gcc13 4.5 gt -fnew)" = "-fnew"
test "$("$gcc_config" gcc13 4.5 lt -fold)" = ""
test "$("$gcc_config" gcc13 14 lt -fold)" = "-fold"
test "$("$gcc_config" gcc13 14 gt -fnew)" = ""
test "$("$gcc_config" gcc13 13.0 gt -fnew)" = ""
test "$("$gcc_config" gcc13 13.0 lt -fold)" = ""

# A two-digit minor is a number, not a string: 13 is older than 13.10.
test "$("$gcc_config" gcc13 13.10 lt -fold)" = "-fold"
