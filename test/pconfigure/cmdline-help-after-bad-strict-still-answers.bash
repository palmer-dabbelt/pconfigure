#include "harness_start.bash"

# Somebody who got an option wrong is exactly who types --help next,
# usually by adding it to the command that just failed.  A --strict
# whose version can't be read is one of those options, and refusing it
# instead of printing the list leaves them with the same error they
# already had.  --help answers before a --srcpath or --config is
# looked at; a --strict value is no more part of what it prints.
echo 'LANGUAGES += c' > Configfile

status=0
$PTEST_BINARY --strict not-a-version --help > help.out 2>&1 || status=$?
cat help.out
test "$status" -eq 0
grep -q "^usage: pconfigure" help.out
test ! -e Makefile
