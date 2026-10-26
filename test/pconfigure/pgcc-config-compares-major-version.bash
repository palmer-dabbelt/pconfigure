#include "harness_start.bash"

# pgcc-config's "gt" and "lt" ask whether the compiler is newer or
# older than a version, and hand back a flag when it is.  They used to
# sort the two versions on their second field alone, so a version with
# a different major was compared by its minor: GCC 4.9 was reported as
# newer than 5.1, because 9 is more than 1, and the major number never
# entered into it.  A flag meant only for compilers newer than 5.1 was
# then handed to a 4.9 that rejects it.
gcc_config="$(dirname "$PTEST_BINARY")/pgcc-config"
test -x "$gcc_config"

mkdir fakebin
cat >fakebin/fakecc <<'EOF'
#!/bin/bash
if [[ "$1" == "-dumpversion" ]]
then
    echo 4.9.2
    exit 0
fi
exit 1
EOF
chmod +x fakebin/fakecc
export PATH="$(pwd)/fakebin:$PATH"

# Same major: what the comparison was written for, and it works.
test "$("$gcc_config" fakecc 4.5 gt -fnew)" = "-fnew"
test "$("$gcc_config" fakecc 4.5 lt -fold)" = ""

# A 4.9 is not newer than 5.1 ...
test "$("$gcc_config" fakecc 5.1 gt -fnewer-than-5)" = ""

# ... and it is older than 5.1.
test "$("$gcc_config" fakecc 5.1 lt -folder-than-5)" = "-folder-than-5"

exit 0
