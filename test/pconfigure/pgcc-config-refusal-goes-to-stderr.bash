#include "harness_start.bash"

# pgcc-config is meant to be run inside a Configfile backtick --
# "COMPILEOPTS += `pgcc-config cc 4.5 gt -fnew-flag`" -- where
# whatever it prints on stdout becomes compiler flags.  It can only
# compare a version that is <major>.<minor> digits, and gives up on a
# compiler whose -dumpversion is anything else, like the "13-win32"
# that a Debian MinGW cross GCC prints.  Saying why on stdout puts the
# explanation on the compile line, so the reason has to go to stderr
# and stdout has to stay empty.
pgcc="$(dirname "$PTEST_BINARY")/pgcc-config"
test -x "$pgcc"

mkdir fakebin
cat >fakebin/mingw-cc <<'EOF'
#!/bin/bash
if [[ "$1" == "-dumpversion" ]]
then
    echo 13-win32
    exit 0
fi
exec cc "$@"
EOF
chmod +x fakebin/mingw-cc
export PATH="$(pwd)/fakebin:$PATH"

set +e
"$pgcc" mingw-cc 4.5 gt -fnew-flag >stdout 2>stderr
status="$?"
set -e
cat stdout stderr

# Giving up is still a failure, and one that says so somewhere a person
# will see it.
test "$status" != "0"
test -s stderr

# Nothing at all on stdout: not the reason, and not the flag either,
# since the version check that would have allowed it never ran.
test ! -s stdout
