#include "harness_start.bash"

# A Configfile line on the command line is read as though it were at
# the top of the first file -- but --help reads no files, so the line
# shouldn't be read either.  A misspelled language in it used to stop
# --help with the same complaint the run without --help gave.
echo 'LANGUAGES += c' > Configfile

status=0
$PTEST_BINARY 'LANGUAGES += cobol' --help > help.out 2>&1 || status=$?
cat help.out
test "$status" -eq 0
grep -q "^usage: pconfigure" help.out
test ! -e Makefile
