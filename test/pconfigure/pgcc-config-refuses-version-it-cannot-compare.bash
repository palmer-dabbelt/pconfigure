#include "harness_start.bash"

# pgcc-config compares versions as numbers in bash arithmetic, which
# reads anything it doesn't recognise as a variable name that's unset,
# so "4.x" would quietly become 4.0 and "gt" would answer a question
# nobody asked.  A version that isn't <major>.<minor> digits is refused
# instead, with the reason on stderr and nothing on stdout -- where it
# would otherwise become words of the compile line -- and a patch level
# is refused too, since the comparison never looks at one and so would
# get "4.5.3 lt" wrong for a 4.5.1.
gcc_config="$(dirname "$PTEST_BINARY")/pgcc-config"
test -x "$gcc_config"

mkdir fakebin
cat >fakebin/fakecc <<'EOF2'
#!/bin/bash
if [[ "$1" == "-dumpversion" ]]
then
    echo 4.5.1
    exit 0
fi
exit 1
EOF2
chmod +x fakebin/fakecc
export PATH="$(pwd)/fakebin:$PATH"

for version in 4.x 4.5.3 four 4. .5
do
    set +e
    "$gcc_config" fakecc "$version" gt -fnew >stdout 2>stderr
    status="$?"
    set -e
    cat stdout stderr

    test "$status" != "0"
    test ! -s stdout
    grep -q -- "$version" stderr
    grep -q "<major>.<minor>" stderr
done

# A version with no minor is a whole release, and is fine.
test "$("$gcc_config" fakecc 4 gt -fnew)" = "-fnew"
test "$("$gcc_config" fakecc 4 lt -fold)" = ""
