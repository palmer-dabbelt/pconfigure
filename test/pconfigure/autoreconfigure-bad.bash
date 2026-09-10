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

##############################################################################
# Below a subproject it was supposed to reach                                #
##############################################################################
# A subproject is read where its line appears, so a tree named above
# this one was read while the answer was still the other one.  Left
# alone that writes the parent's Makefile one way and the child's the
# other and says nothing about it, which looks exactly like a tree
# where the mode does not work.
setup
mkdir -p case/sub/src
cat >case/sub/Configfile <<EOF
LANGUAGES       += c

BINARIES        += sub
SOURCES         += sub.c
EOF

cat >case/sub/src/sub.c <<EOF
int main(void) { return 0; }
EOF

cat >case/Configfile <<EOF
SUBPROJECTS     += sub

AUTORECONFIGURE  = true

LANGUAGES       += c

BINARIES        += main
SOURCES         += main.c
EOF

refuses
grep -q "a subproject has already been read" out
grep -q "move it above the first SUBPROJECTS or BOOTSTRAP line" out
grep -q "Configfile:3" out

##############################################################################
# Below the tree a BOOTSTRAP named                                           #
##############################################################################
# The same mistake in the spelling nobody expects: a BOOTSTRAP names a
# vendored pconfigure and reads it as a subproject, so a Configfile
# that opens with one and says AUTORECONFIGURE underneath has already
# read a tree by line two.
setup
mkdir -p case/vendor/pconfigure
echo "#!/bin/bash" > case/vendor/pconfigure/bootstrap.sh
chmod +x case/vendor/pconfigure/bootstrap.sh

cat >case/Configfile <<EOF
BOOTSTRAP        = vendor/pconfigure

AUTORECONFIGURE  = true

LANGUAGES       += c

BINARIES        += main
SOURCES         += main.c
EOF

refuses
grep -q "a subproject has already been read" out

##############################################################################
# Saying again what was already true                                         #
##############################################################################
# Not every line below a subproject is a mistake.  A Configfile that
# writes down the default it was already getting has changed nothing,
# and refusing it would be refusing a project for being explicit.
setup
mkdir -p case/sub/src
cat >case/sub/Configfile <<EOF
LANGUAGES       += c

BINARIES        += sub
SOURCES         += sub.c
EOF

cat >case/sub/src/sub.c <<EOF
int main(void) { return 0; }
EOF

cat >case/Configfile <<EOF
SUBPROJECTS     += sub

AUTORECONFIGURE  = false

LANGUAGES       += c

BINARIES        += main
SOURCES         += main.c
EOF

(cd case && $PTEST_BINARY $PCONFIGURE_ARGS)
test -e case/Makefile

exit 0
