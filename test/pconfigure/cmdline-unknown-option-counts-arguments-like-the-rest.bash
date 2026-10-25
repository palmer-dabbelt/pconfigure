#include "harness_start.bash"

# Each command-line word is numbered when pconfigure talks about it:
# "--strict v9x" is refused as "args:1 '--strict v9x'", counting from one
# the way argv does once the program name is off it.  The refusal of
# an option nobody has heard of used to count from zero instead, so
# in "--verbose extra" the stray "extra", the second word, was called
# "option 1": the number of the --verbose in front of it.  Two
# messages from one program about one command line should count the
# same way.
echo 'LANGUAGES += c' > Configfile

status=0
$PTEST_BINARY --strict v9x >strict.out 2>&1 || status=$?
cat strict.out
test "$status" -ne 0
grep -q "args:1 '--strict v9x'" strict.out

status=0
$PTEST_BINARY --verbose extra >out 2>&1 || status=$?
cat out
test "$status" -ne 0
test ! -e Makefile
grep -q "option 2: 'extra'" out
