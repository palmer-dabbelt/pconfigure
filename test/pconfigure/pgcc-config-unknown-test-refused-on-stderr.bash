#include "harness_start.bash"

# pgcc-config knows two tests, "gt" and "lt".  Anything else -- "ge",
# say, which reads naturally beside them -- is refused, on stderr and
# with a failing status, so that a Configfile backtick stops rather
# than silently pasting nothing (or a sentence) into the compile flags.
gcc_config="$(dirname "$PTEST_BINARY")/pgcc-config"
test -x "$gcc_config"

mkdir fakebin
cat >fakebin/fakecc <<'EOF'
#!/bin/bash
if [[ "$1" == "-dumpversion" ]]
then
    echo 4.7.1
    exit 0
fi
exit 1
EOF
chmod +x fakebin/fakecc
export PATH="$(pwd)/fakebin:$PATH"

set +e
"$gcc_config" fakecc 4.5 ge -fnew >ge.out 2>ge.err
status="$?"
set -e
cat ge.err
test "$status" != "0"
test ! -s ge.out
grep -q "Unsupported test ge" ge.err

exit 0
