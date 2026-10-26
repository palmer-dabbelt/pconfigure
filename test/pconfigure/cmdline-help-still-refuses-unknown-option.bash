#include "harness_start.bash"

# --help leaves the Configfile lines typed beside it unread, but a word
# that starts with a dash was never going to be one of those: it is an
# option somebody misspelled, and saying so is more use to them than
# the list with nothing pointing at the word that was wrong.  The
# refusal is the same one the run without --help gives, and it names
# --help for the list.
echo 'LANGUAGES += c' > Configfile

status=0
$PTEST_BINARY --bogus --help > out 2>&1 || status=$?
cat out
test "$status" -eq 134
grep -q -- "Unable to parse command-line option 1: '--bogus'" out
test ! -e Makefile

# The same goes for --version.
status=0
$PTEST_BINARY --version --bogus > out 2>&1 || status=$?
cat out
test "$status" -eq 134
grep -q -- "Unable to parse command-line option 2: '--bogus'" out
test ! -e Makefile
