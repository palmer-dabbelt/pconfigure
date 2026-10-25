#include "harness_start.bash"

# A suite name is written against the command, "TESTSRC[net]", and a
# space before the bracket is an easy slip.  That makes "[net]" the
# second word, which is where the operator goes, and the line used to
# be read that way: it was warned about for having a space in a file
# name and then refused because "TESTSRC has a '=' in it: '+= t.bash'",
# with advice to rename the test without the '='.  None of that is the
# mistake, so the refusal is about the bracket in the operator's place.
mkdir -p src test/main
echo 'int main(void) { return 0; }' > src/main.c
printf '#!/bin/bash\nexit 0\n' > test/main/t.bash

# Each line is refused, naming the line and never with advice about a
# file name; the second argument is what the refusal has to say.
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
    if grep -q "has a '=' in it" out
    then
        exit 1
    fi
    if grep -q "space in its name" out
    then
        exit 1
    fi
    test ! -e Makefile
}

# Only the space is wrong, with the operator either its own word or
# run up against the ']', so the line is given back without it.
refused 'TESTSRC [net] += t.bash' "write 'TESTSRC[net] += t.bash'"
refused 'TESTSRC [net]+= t.bash' "write 'TESTSRC[net] += t.bash'"
refused 'TESTSRC [net] +=t.bash' "write 'TESTSRC[net] += t.bash'"

# Text after the ']' that starts with an operator is an operator with
# the spaces round it left out, not something that isn't one.
refused 'TESTSRC [net]=t.bash' "write 'TESTSRC[net] = t.bash'"
if grep -q "not an operator" out
then
    exit 1
fi
refused 'TESTSRC [net]+=' "nothing comes after the '+='"
if grep -q "not an operator" out
then
    exit 1
fi

# A second mistake on top of the space means taking the space out
# leaves a line that still doesn't work, so nothing claims to be the
# corrected line: what's wrong is pointed at instead.
refused 'TESTSRC [net]x += t.bash' "'x' after the ']' is not an operator"
if grep -qF "write 'TESTSRC[net] " out
then
    exit 1
fi
refused 'TESTSRC [net] t.bash' "no operator after it"
if grep -qF "write 'TESTSRC[net] " out
then
    exit 1
fi

# A command that already has its name can't be given a second one,
# and that second one is still sitting where the operator goes.
refused 'TESTSRC[net] [x] += t.bash' "no operator starts with a '['"
grep -qF "already carries a name" out
