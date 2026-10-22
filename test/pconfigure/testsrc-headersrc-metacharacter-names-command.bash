#include "harness_start.bash"

# A shell metacharacter in a TESTSRC or a HEADERSRC is refused, and
# the refusal has to be in the words of the line that was written for
# the same reason an escaping path's is: "write SOURCES without one"
# points at a SOURCES line this Configfile doesn't have.  It is the
# line as written that is now asked about a ';', before either half
# of the pair is processed, but that is no excuse to name the wrong
# command.
mkdir -p src test/main include
echo 'int main(void) { return 0; }' > src/main.c
echo 'true' > test/main/t.bash

for command in TESTSRC HEADERSRC
do
    cat >Configfile <<EOF2
LANGUAGES += c
LANGUAGES += bash

BINARIES  += main
SOURCES   += main.c
$command += x;touch PWNED
EOF2
    cat Configfile
    rm -f Makefile

    if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
    then
        echo "$command with a ';' in it was accepted" >&2
        exit 1
    fi
    cat out

    grep -q "Configfile:6" out
    grep -q "error: $command has a ';' in it" out
    grep -q "rename it without the ';'" out
    if grep -q "SOURCES has\|write SOURCES" out
    then
        echo "$command was reported as a SOURCES" >&2
        exit 1
    fi
    test ! -e Makefile
    test ! -e PWNED
done
