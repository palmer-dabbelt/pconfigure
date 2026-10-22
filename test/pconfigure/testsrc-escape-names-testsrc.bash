#include "harness_start.bash"

# A TESTSRC is a TESTS and a SOURCES written on one line, and the
# SOURCES half is the one that asks whether the path leaves the
# project.  The refusal is right; what it says is not, if it says
# "SOURCES" -- the Configfile has no SOURCES line for whoever reads
# it to go and find, and the suggestion "SOURCES += main.c" names no
# test at all, so following it loses the test the line was there to
# add.  The diagnostic has to name the command that was written and
# suggest a line of that command's own shape.
#
# All three spellings of leaving are tried, since each takes a
# different branch of leaves_the_project() on its way to the same
# message, and the suite-qualified TESTSRC goes through the same door.
mkdir -p src test/main
echo 'int main(void) { return 0; }' > src/main.c
echo 'true' > test/main/t.bash

for line in "TESTSRC += ../escape.bash" \
            "TESTSRC += /abs/escape.bash" \
            'TESTSRC += $(HOME)/x.bash' \
            "TESTSRC[network] += ../escape.bash"
do
    cat >Configfile <<EOF2
LANGUAGES += c
LANGUAGES += bash

BINARIES  += main
SOURCES   += main.c
$line
EOF2
    cat Configfile
    rm -f Makefile

    if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
    then
        echo "'$line' was accepted" >&2
        exit 1
    fi
    cat out

    grep -q "Configfile:6" out
    grep -q "error: TESTSRC names a file outside this project" out
    grep -q "like 'TESTSRC += " out
    if grep -q "SOURCES names\|'SOURCES +=" out
    then
        echo "'$line' was reported as a SOURCES" >&2
        exit 1
    fi
    test ! -e Makefile
done
