#include "harness_start.bash"

# --help is answered before any Configfile is read, so options that
# only matter once one is -- a --srcpath that doesn't exist, a
# --config naming nothing -- don't stop it, and nothing is written.
# Somebody who has got the options wrong is exactly who types --help
# next, usually by adding it to the command they just ran.
if ! $PTEST_BINARY --srcpath does/not/exist --config nothing --help \
        > help.out 2>&1
then
    cat help.out
    exit 1
fi
cat help.out
grep -q "^usage: pconfigure" help.out

# Nothing at all, not just no Makefile: the directory holds only what
# this script redirected into it.
test "$(ls -A)" = help.out

# The same goes for --version.
$PTEST_BINARY --srcpath does/not/exist --version > version.out 2>&1
grep -q "^pconfigure " version.out
test "$(ls -A | tr '\n' ' ')" = "help.out version.out "
