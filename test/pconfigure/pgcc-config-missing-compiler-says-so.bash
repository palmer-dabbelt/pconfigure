#include "harness_start.bash"

# Asked to compare the version of a compiler that isn't installed,
# pgcc-config used to run "<program> -dumpversion", get nothing back,
# and then explain that the program "reports version , but only GCC
# 4.x versions can be compared" -- blaming the version of a program
# that never ran.  The refusal has to say the compiler couldn't be run,
# and name it, so the person reading it goes looking for the compiler
# rather than wondering which version it was.
gcc_config="$(dirname "$PTEST_BINARY")/pgcc-config"
test -x "$gcc_config"

set +e
"$gcc_config" no-such-cc-anywhere 4.5 gt -fnew >missing.out 2>missing.err
status="$?"
set -e
cat missing.out missing.err

test "$status" != "0"
test ! -s missing.out
if grep -q -e "only GCC 4.x versions can be compared" -e "isn't a <major>.<minor> version" missing.err
then
    exit 1
fi
grep -q "pgcc-config: could not run no-such-cc-anywhere -dumpversion" missing.err
