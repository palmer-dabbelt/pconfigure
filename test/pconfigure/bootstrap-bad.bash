#include "harness_start.bash"

# The trees a BOOTSTRAP isn't allowed to name.  The Makefile this
# command writes is one that gets committed and handed to strangers,
# so every one of these is a mistake that would travel: it works on
# the machine it was written on and says nothing useful anywhere else.

# Rebuilt from scratch for each case, since the point of every one of
# them is that no Makefile comes out the far side.
setup() {
    rm -rf case
    mkdir -p case/src

    cat >case/src/main.c <<EOF
int main(void) { return 0; }
EOF
}

# A tree that looks enough like pconfigure's own to be bootstrapped
# from: the script is what gets run, so the script is what's looked
# for.
vendor() {
    mkdir -p "case/$1"
    echo "#!/bin/bash" > "case/$1/bootstrap.sh"
    chmod +x "case/$1/bootstrap.sh"
}

# The subshell is the assertion: "set -e" is on, so a command expected
# to fail has to be somewhere a failure isn't fatal.  It stopping
# before it wrote anything is part of what's being checked -- a
# half-configured tree is something the next command trips over.
refuses() {
    if (cd case && $PTEST_BINARY $PCONFIGURE_ARGS) > out 2>&1
    then
        exit 1
    fi
    cat out
    test ! -e case/Makefile
    test ! -e case/Makefile.pconfigure
}

##############################################################################
# With the wrong operator                                                    #
##############################################################################
# There is one pconfigure a project is built with, so there is nothing
# a second line could be adding to.
setup
vendor vendor/pconfigure
cat >case/Configfile <<EOF
LANGUAGES += c

BOOTSTRAP += vendor/pconfigure

BINARIES  += main
SOURCES   += main.c
EOF

refuses
grep -q "only supports '='" out

##############################################################################
# Pointing at the project itself                                             #
##############################################################################
# A project that bootstrapped from itself would have to have been
# built before it could be built.
setup
cat >case/Configfile <<EOF
LANGUAGES += c

BOOTSTRAP  = .

BINARIES  += main
SOURCES   += main.c
EOF

refuses
grep -q "can't point at the project itself" out

##############################################################################
# Pointing outside the tree                                                  #
##############################################################################
# The Makefile that names it is committed, so a path that leaves the
# tree names nothing on anybody else's machine.
setup
vendor ../outside
cat >case/Configfile <<EOF
LANGUAGES += c

BOOTSTRAP  = ../outside

BINARIES  += main
SOURCES   += main.c
EOF

refuses
grep -q "can't reach outside the project" out

##############################################################################
# Pointing at something that isn't a pconfigure source tree                  #
##############################################################################
# The usual way to arrive here is a submodule nobody has checked out,
# which leaves an empty directory behind.  Left to make that comes out
# as a missing Makefile, which says nothing about submodules.
setup
mkdir -p case/vendor/pconfigure
cat >case/Configfile <<EOF
LANGUAGES += c

BOOTSTRAP  = vendor/pconfigure

BINARIES  += main
SOURCES   += main.c
EOF

refuses
grep -q "has no executable bootstrap.sh" out
grep -q "git submodule update --init vendor/pconfigure" out

##############################################################################
# Naming a tree this build also builds                                       #
##############################################################################
# A vendored pconfigure is either something this build builds or
# something that builds itself, and it can't be both: as a subproject
# the tree is configured from up here into this build's directories,
# and bootstrapping it configures it for itself.  Each of those writes
# the Makefile the other one reads.
setup
vendor vendor/pconfigure
mkdir -p case/vendor/pconfigure/src
cat >case/vendor/pconfigure/Configfile <<EOF
LANGUAGES += c

BINARIES  += pconfigure
SOURCES   += pconfigure.c
EOF

cat >case/vendor/pconfigure/src/pconfigure.c <<EOF
int main(void) { return 0; }
EOF

cat >case/Configfile <<EOF
SUBPROJECTS += vendor/pconfigure

BOOTSTRAP    = vendor/pconfigure

LANGUAGES   += c

BINARIES    += main
SOURCES     += main.c
EOF

refuses
grep -q "is a subproject of this build as well as the pconfigure it" out

# And the other way around, since which of the two lines came first
# isn't what's wrong with them.
cat >case/Configfile <<EOF
BOOTSTRAP    = vendor/pconfigure

SUBPROJECTS += vendor/pconfigure

LANGUAGES   += c

BINARIES    += main
SOURCES     += main.c
EOF

refuses
grep -q "is a subproject of this build as well as the pconfigure it" out

##############################################################################
# Written in a subproject                                                    #
##############################################################################
# The rules a BOOTSTRAP writes go in the Makefile make is run at, and
# a subproject's Makefile is included by that one -- so a second copy
# down here would be a second recipe for the same file.
setup
mkdir -p case/sub/src
vendor sub/vendor/pconfigure
cat >case/Configfile <<EOF
SUBPROJECTS += sub

LANGUAGES   += c

BINARIES    += main
SOURCES     += main.c
EOF

cat >case/sub/Configfile <<EOF
LANGUAGES += c

BOOTSTRAP  = vendor/pconfigure

BINARIES  += sub
SOURCES   += sub.c
EOF

cat >case/sub/src/sub.c <<EOF
int main(void) { return 0; }
EOF

refuses
grep -q "in a subproject has no Makefile to write" out

exit 0
