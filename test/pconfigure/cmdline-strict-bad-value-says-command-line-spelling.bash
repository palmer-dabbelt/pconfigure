#include "harness_start.bash"

# "--strict" with a value that isn't a version is refused by the same
# code that refuses a Configfile's "STRICT = ...", and that code used
# to give the same advice either way: "it's written the way a release
# is written: 'STRICT = v0.13'".  That is the Configfile spelling, and
# somebody who typed "--strict v9x" at a shell can't put it back where
# they typed the mistake.  The location was no better: it quoted
# "args:1 '--strict'", which is the one word on that command line that
# was fine, and left out the value that wasn't.
echo 'LANGUAGES += c' > Configfile

if $PTEST_BINARY --strict v9x >out 2>&1
then
    cat out
    exit 1
fi
cat out

# Refused before anything was written, the way a bad Configfile line
# is.
test ! -e Makefile

# The location names the flag and the value together, since the value
# is what's wrong and the flag is what says which value it is.
grep -q "^args:1 '--strict v9x'\$" out

# Then the same complaint a Configfile gets about what's wrong with the
# value, and advice spelled the way this one was asked for.
grep -q "STRICT wants a pconfigure version, and 'v9x' isn't a number" out
grep -q -- "'--strict v0.13'" out
if grep -q "STRICT = " out
then
    exit 1
fi

# A value that came from a Configfile still gets the Configfile
# spelling: the fix is for where the value came from, not a new
# spelling for everybody.
cat > Configfile <<EOT
STRICT    = v9x
LANGUAGES += c
EOT

if $PTEST_BINARY >cf.out 2>&1
then
    cat cf.out
    exit 1
fi
cat cf.out

grep -q "^\./Configfile:1 'STRICT = v9x'\$" cf.out
grep -q "'STRICT = v0.13'" cf.out
if grep -q -- "--strict" cf.out
then
    exit 1
fi
