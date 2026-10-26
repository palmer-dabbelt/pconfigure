#include "harness_start.bash"

# Asked whether a 4.5 compiler is newer than 4.5, pgcc-config used to
# say yes; asked whether it is older than 4.5, it also said yes.  "gt"
# and "lt" both decided by which version sorted first and last, and
# with the two equal either one is both, so a Configfile that hands one
# flag to compilers newer than a version and another to compilers
# older than it got both flags for the version on the boundary.
#
# "gt" and "lt" are strict: a compiler of exactly the named version is
# neither newer nor older, so neither flag comes back.  The patch level
# isn't part of the comparison, so 4.5.0 is exactly 4.5.
gcc_config="$(dirname "$PTEST_BINARY")/pgcc-config"
test -x "$gcc_config"

mkdir fakebin
cat >fakebin/fakecc <<'EOF'
#!/bin/bash
if [[ "$1" == "-dumpversion" ]]
then
    echo 4.5.0
    exit 0
fi
exit 1
EOF
chmod +x fakebin/fakecc
export PATH="$(pwd)/fakebin:$PATH"

gt="$("$gcc_config" fakecc 4.5 gt -fnew)"
lt="$("$gcc_config" fakecc 4.5 lt -fold)"
echo "gt='$gt' lt='$lt'"

test "$gt" = ""
test "$lt" = ""

# Either side of the boundary still gets its flag.
test "$("$gcc_config" fakecc 4.4 gt -fnew)" = "-fnew"
test "$("$gcc_config" fakecc 4.6 lt -fold)" = "-fold"
