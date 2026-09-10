#include "harness_start.bash"

# AUTORECONFIGURE says who works out this project's dependencies:
# pconfigure, once, or the build, every time it runs.  There are two
# answers to that and no third one, so the ways of writing it wrong
# are the ways of writing a boolean wrong -- and each of them has to
# stop before a Makefile is written, because a Makefile whose
# dependencies came from a line nobody understood is worse than none.

setup() {
    rm -rf case
    mkdir -p case/src

    cat >case/src/main.c <<EOF
int main(void) { return 0; }
EOF
}

# The subshell is the assertion: "set -e" is on, so a command expected
# to fail has to be somewhere a failure isn't fatal.  It stopping
# before it wrote anything is part of what's being checked.
refuses() {
    if (cd case && $PTEST_BINARY $PCONFIGURE_ARGS) > out 2>&1
    then
        exit 1
    fi
    cat out
    test ! -e case/Makefile
}

##############################################################################
# With the wrong operator                                                    #
##############################################################################
# A project has one answer to this, so there is nothing a second line
# could be adding to.
setup
cat >case/Configfile <<EOF
LANGUAGES       += c

AUTORECONFIGURE += true

BINARIES        += main
SOURCES         += main.c
EOF

refuses
grep -q "only supports '='" out

##############################################################################
# With something that isn't a boolean                                        #
##############################################################################
# "yes" is what half the world writes here, and taking it would mean
# guessing.  The line is named, because the value alone doesn't say
# which of several booleans in a Configfile was the one written wrong.
setup
cat >case/Configfile <<EOF
LANGUAGES       += c

AUTORECONFIGURE  = yes

BINARIES        += main
SOURCES         += main.c
EOF

refuses
grep -q "'yes' is not 'true' or 'false'" out
grep -q "Configfile:3" out

exit 0
