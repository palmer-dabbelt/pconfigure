#include "harness_start.bash"

# pgcc-config run without enough arguments prints its usage and fails.
# Inside a Configfile backtick the usage would become compiler flags if
# it went to stdout, so it belongs on stderr.  The usage also mentions
# "`program -dumpversion`" in backquotes, which must come out as text
# rather than being run as a command that doesn't exist.
pgcc="$(dirname "$PTEST_BINARY")/pgcc-config"
test -x "$pgcc"

set +e
"$pgcc" >stdout 2>stderr
status="$?"
set -e
cat stdout stderr

test "$status" != "0"
test ! -s stdout
grep -qF 'pgcc-config <program> <version> [test] [flag]' stderr
grep -qF '`program -dumpversion`' stderr
if grep -q "command not found" stderr
then
    exit 1
fi
