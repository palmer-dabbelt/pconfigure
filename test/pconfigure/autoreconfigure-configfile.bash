#include "harness_start.bash"

# Under AUTORECONFIGURE the build is what keeps itself current, and a
# Configfile was the one input to it that nothing watched.  Everywhere
# else that stays deliberate -- see reconfigure.bash, which checks the
# opposite and is still right -- because a build that reconfigured on
# its own would decide, by itself, to throw away whatever the new
# options touched.
#
# The interesting half is the subproject.  A subproject cannot be
# configured from inside itself, so its Configfile changing has to
# re-run the pconfigure at the top of the tree.

# The rule runs whatever the PATH calls "pconfigure", the same as
# "make reconfigure" does, so the PATH is what has to be pointed at
# the one under test.
export PATH="$(dirname "$PTEST_BINARY"):$PATH"

tree() {
    mkdir -p "$1/src" "$1/sub/src"
    (
        cd "$1"
        {
            test "$2" = "on" && echo "AUTORECONFIGURE = true"
            cat <<'CONFIGFILE'
SUBPROJECTS    += sub

LANGUAGES      += c++

BINARIES       += top
COMPILEOPTS    += -Isub/src
LINKOPTS       += -Lsub/lib
LINKOPTS       += -lsub
SOURCES        += top.c++
CONFIGFILE
        } > Configfile

        cat >sub/Configfile <<'CONFIGFILE'
LANGUAGES      += c++

LIBRARIES      += libsub.a
SOURCES        += sub.c++
CONFIGFILE

        cat >sub/src/sub.h++ <<'SOURCE'
int sub(void);
SOURCE

        cat >sub/src/sub.c++ <<'SOURCE'
  #include "sub.h++"
int sub(void) { return 1; }
SOURCE

        cat >src/top.c++ <<'SOURCE'
  #include "sub.h++"
  #include <cstdio>
int main(void) { printf("%d\n", sub()); return 0; }
SOURCE
    )
}

##############################################################################
# Off unless asked for                                                       #
##############################################################################
tree off off
(cd off && $PTEST_BINARY $PCONFIGURE_ARGS)
if grep -q "^Makefile:" off/Makefile
then
    exit 1
fi

##############################################################################
# What the rule says                                                         #
##############################################################################
tree on on
(cd on && $PTEST_BINARY $PCONFIGURE_ARGS && make $MAKE_ARGS)
test "$(./on/bin/top)" = "1"

grep -q "^Makefile:" on/Makefile

# Every name a run went looking in, whether or not it was there.  The
# ones that are missing are the point: a Configfile.local that gets
# written for the first time has to be noticed too, and $(wildcard) is
# what lets an absent file be named without stopping make.
grep -q '\$(wildcard Configfile)' on/Makefile
grep -q '\$(wildcard Configfiles/main)' on/Makefile
grep -q '\$(wildcard Configfile.local)' on/Makefile
grep -q '\$(wildcard Configfiles/local)' on/Makefile

# Including the subproject's, because that is who has to run
# pconfigure when one of those changes.
grep -q '\$(wildcard sub/Configfile)' on/Makefile

# And the subproject gets no rule of its own.  Its Makefile is
# included by this one, and make ignores an out-of-date included
# makefile that has prerequisites and no recipe -- so a copy down
# there would say nothing and hide that it said nothing.
if grep -q "^Makefile:" on/sub/Makefile
then
    exit 1
fi

##############################################################################
# A second make                                                              #
##############################################################################
# Nothing changed, so nothing happens.  This is the assertion that
# fails if the Makefile ever stops being rewritten on every configure:
# a recipe that leaves its own target older than a prerequisite is a
# recipe make runs again on every single invocation, forever.
(cd on && make $MAKE_ARGS) > on/second.log 2>&1
cat on/second.log
grep -q "Nothing to be done" on/second.log
if grep -q "^PCONFIGURE$" on/second.log
then
    exit 1
fi

##############################################################################
# A subproject's Configfile that changed                                     #
##############################################################################
# The whole point.  A source is added to the subproject by editing the
# subproject's Configfile, and a plain "make" at the top builds and
# links it, with nobody running pconfigure by hand.
cat >on/sub/src/added.c++ <<'SOURCE'
int added(void) { return 40; }
SOURCE

cat >on/sub/src/sub.c++ <<'SOURCE'
  #include "sub.h++"
int added(void);
int sub(void) { return added() + 2; }
SOURCE

cat >on/sub/Configfile <<'CONFIGFILE'
LANGUAGES      += c++

LIBRARIES      += libsub.a
SOURCES        += sub.c++
SOURCES        += added.c++
CONFIGFILE

sleep 1
(cd on && make $MAKE_ARGS) > on/third.log 2>&1
cat on/third.log
grep -q "^PCONFIGURE$" on/third.log
test "$(./on/bin/top)" = "42"

##############################################################################
# A Configfile that did not exist before                                     #
##############################################################################
# $(wildcard) is expanded again on every run, so the day one of the
# names that was empty stops being empty, it is a prerequisite newer
# than the Makefile.
# It declares its own language, because a Configfile.local is read
# before the Configfile is: it is where somebody's private overrides
# go, so it gets to have an opinion before the project states one.
cat >on/Configfile.local <<'CONFIGFILE'
LANGUAGES      += c++

BINARIES       += extra
SOURCES        += extra.c++
CONFIGFILE

cat >on/src/extra.c++ <<'SOURCE'
int main(void) { return 0; }
SOURCE

sleep 1
(cd on && make $MAKE_ARGS) > on/fourth.log 2>&1
cat on/fourth.log
grep -q "^PCONFIGURE$" on/fourth.log
test -e on/bin/extra

##############################################################################
# And one that stopped existing                                              #
##############################################################################
# Not noticed, and that is the trade rather than an oversight: the
# $(wildcard) that lets a missing file be named is the same thing that
# makes its removal invisible.  What matters is that the build still
# works, since a name that vanished out of a prerequisite list would
# otherwise stop make outright.
rm on/Configfile.local
sleep 1
(cd on && make $MAKE_ARGS) > on/fifth.log 2>&1
cat on/fifth.log
test "$(./on/bin/top)" = "42"

exit 0
