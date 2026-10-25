#include "harness_start.bash"

# An option pconfigure doesn't know is refused, and the refusal used to
# open with two lines of parser internals -- "split_char() returned 1"
# and "original string: '--bogus'" -- before getting to "Unable to
# parse command-line option".  Those are about how the word was taken
# apart rather than about what was typed, and they were the first
# thing anybody saw.  What does help, "--help" listing what there is,
# wasn't mentioned at all.
echo 'LANGUAGES += c' > Configfile

status=0
$PTEST_BINARY --bogus >out 2>&1 || status=$?
cat out
test "$status" -eq 134
test ! -e Makefile
grep -q -- "Unable to parse command-line option 1: '--bogus'" out
grep -q -- "pconfigure --help" out
if grep -q -e "split_char" -e "original string" out
then
    exit 1
fi

# The same parser reads Configfile lines, and a line too short to be a
# command was leaking the same two lines ahead of the refusal that
# names the file and line.
echo 'LANGUAGES' > Configfile
status=0
$PTEST_BINARY >out 2>&1 || status=$?
cat out
test "$status" -eq 134
test ! -e Makefile
grep -q "Configfile:1: 'LANGUAGES'" out
if grep -q -e "split_char" -e "original string" out
then
    exit 1
fi
