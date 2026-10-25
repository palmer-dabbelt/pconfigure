#include "harness_start.bash"

# "--ccmd NAME" points ppkg-config at a NAME-config program instead of
# pkg-config (the manual's example is gpgme-config), and everything
# else -- the arguments, --optional, --have -- still applies.  The
# fake tool records what it was asked so the test can see the
# arguments went through untouched.
ppkg="$(dirname "$PTEST_BINARY")/ppkg-config"
test -x "$ppkg"

mkdir fakebin
cat >fakebin/thing-config <<'EOF'
#!/bin/bash
echo "$@" >>"$THING_LOG"
case "$1" in
--cflags) echo "-I/opt/thing/include" ;;
--libs)   echo "-L/opt/thing/lib -lthing" ;;
*)        exit 1 ;;
esac
EOF
chmod +x fakebin/thing-config
export PATH="$(pwd)/fakebin:$PATH"
export THING_LOG="$(pwd)/thing.log"

test "$("$ppkg" --ccmd thing --cflags)" = "-I/opt/thing/include"
test "$("$ppkg" --ccmd thing --have THING --libs)" \
    = "-L/opt/thing/lib -lthing -DHAVE_THING"
cat thing.log
test "$(sed -n 1p thing.log)" = "--cflags"
test "$(sed -n 2p thing.log)" = "--libs"

# A tool that isn't installed at all is a failure, unless --optional.
set +e
"$ppkg" --ccmd nosuchtool --cflags
status="$?"
set -e
test "$status" != "0"
test "$("$ppkg" --optional --ccmd nosuchtool --cflags)" = ""

exit 0
