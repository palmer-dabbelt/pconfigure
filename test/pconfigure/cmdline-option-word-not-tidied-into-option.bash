#include "harness_start.bash"

# A word on the command line that isn't an option is a Configfile line,
# and a Configfile line is tidied and has its backticks run before it's
# read.  An option isn't: it's matched exactly as it was typed, and the
# word an option takes after it is a name, used exactly as given.  Doing
# the tidying first would turn ' --srcpath' into the option --srcpath
# after the word it needed had already gone by as something else, and
# would quietly rename a CONFIG somebody really did call 'a  b'.
echo 'LANGUAGES += c' > Configfile

status=0
$PTEST_BINARY ' --srcpath' elsewhere > out 2>&1 || status=$?
cat out
test "$status" -ne 0
test ! -e Makefile
grep -q -- "Unable to parse command-line option 1: ' --srcpath'" out

status=0
$PTEST_BINARY --config 'a  b' > out 2>&1 || status=$?
cat out
test "$status" -ne 0
test ! -e Makefile
grep -q -- "Configfiles/a  b nor" out
