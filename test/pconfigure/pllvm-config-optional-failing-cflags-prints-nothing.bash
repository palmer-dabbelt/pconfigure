#include "harness_start.bash"

# With llvm-config present but failing to answer --cflags (a broken
# install, or one for another machine), pllvm-config --optional
# succeeds and prints nothing at all, and without --optional it passes
# llvm-config's status on.  Nothing of what llvm-config managed to
# print before failing may reach stdout either way, since a backtick
# would paste it into the compile flags.
llvm="$(dirname "$PTEST_BINARY")/pllvm-config"
test -x "$llvm"

mkdir fakebin
cat >fakebin/llvm-config <<'EOF'
#!/bin/bash
case "$1" in
--version) echo 15.0.0 ;;
--cflags)
    echo "-I/half/an/answer"
    echo "llvm-config: error: broken install" >&2
    exit 3
    ;;
esac
EOF
chmod +x fakebin/llvm-config
export PATH="$(pwd)/fakebin:$PATH"

set +e
"$llvm" --optional --cflags >optional.out
status="$?"
set -e
test "$status" = "0"
test ! -s optional.out

set +e
"$llvm" --cflags >required.out 2>required.err
status="$?"
set -e
test "$status" = "3"
test ! -s required.out
grep -q "broken install" required.err

exit 0
