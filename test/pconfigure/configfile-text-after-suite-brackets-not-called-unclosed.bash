#include "harness_start.bash"

# "TESTSRC[net]x" has its brackets closed; what's wrong is the 'x'
# after them.  It was refused as a name that "opens a name in brackets
# and never closes it", which sends whoever reads it looking for a
# missing ']' that is right there -- or, with too few words left on the
# line, only as a line that couldn't be parsed.  The line is still
# refused, naming it, but for what is actually wrong with it.
mkdir -p src test/main
echo 'int main(void) { return 0; }' > src/main.c
printf '#!/bin/bash\nexit 0\n' > test/main/t.bash

refused() {
    cat >Configfile <<END
LANGUAGES   += c
LANGUAGES   += bash
TEST_SUITES += net
BINARIES    += main
SOURCES     += main.c
$1
END

    if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
    then
        cat out
        exit 1
    fi
    cat out
    grep -q "Configfile:6" out
    grep -qF -- "$2" out
    if grep -q "never closes" out
    then
        exit 1
    fi
    if grep -q "Unable to parse" out
    then
        exit 1
    fi
    test ! -e Makefile
}

refused 'TESTSRC[net]x += t.bash' "'x' after the ']'"
refused 'TESTSRC[net]x' "'x' after the ']'"

# The operator run up against the ']' is the likeliest thing to find
# there, and with one file after it the line is only two words long.
# Only the space is missing, so the line is given back with it in.
refused 'TESTSRC[net]+= t.bash' "write 'TESTSRC[net] += t.bash'"
refused 'TESTSRC[net]+= t.bash u.bash' "write 'TESTSRC[net] += t.bash u.bash'"

# The value can be run up against the operator as well, and that is
# still only spacing: moving the operator and the file into the suite's
# name would never be the fix, so that isn't what the refusal says.
refused 'TESTSRC[net]+=t.bash' "write 'TESTSRC[net] += t.bash'"
grep -qF "space on each side" out
if grep -q "inside the brackets" out
then
    exit 1
fi
refused 'TESTSRC[net]=t.bash' "write 'TESTSRC[net] = t.bash'"
if grep -q "inside the brackets" out
then
    exit 1
fi

# A name written in front of its command has the command after the
# ']', and ending the word at the ']' would leave the line with no
# command at all.  The name goes the other side of it instead.
refused '[net]TESTSRC += t.bash' "write 'TESTSRC[net] += t.bash'"
if grep -q "nothing after the ']'" out
then
    exit 1
fi
refused '[net]TESTSRC t.bash' "write 'TESTSRC[net]', then the operator"
