#include "harness_start.bash"
#pconfigure TESTDEPS += bin/pdeps

# Who works out the dependencies is a property of the build, not of
# one Configfile.  A subproject's Makefile is included by the one make
# was actually run on, so both halves are read by the same make -- and
# a tree whose parent asked for the build to keep itself current is a
# tree nobody is going to configure again by hand.
#
# So a SUBPROJECTS inherits AUTORECONFIGURE, and the thing being
# checked here is the consequence: an "#include" added to a
# subproject's source is followed by a plain "make", with nobody
# running pconfigure in between.

# A subproject whose walk has somewhere to go.  "buried.c++" is named
# by no Configfile anywhere and is reachable only behind a header that
# "sub.c++" reads, so a build that finds it is a build that did the
# walk.
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

        {
            test "$3" = "off" && echo "AUTORECONFIGURE = false"
            cat <<'CONFIGFILE'
LANGUAGES      += c++

LIBRARIES      += libsub.a
SOURCES        += sub.c++
CONFIGFILE
        } > sub/Configfile

        cat >sub/src/sub.h++ <<'SOURCE'
int sub(void);
SOURCE

        cat >sub/src/buried.h++ <<'SOURCE'
int buried(void);
SOURCE

        cat >sub/src/buried.c++ <<'SOURCE'
int buried(void) { return 4; }
SOURCE

        cat >sub/src/sub.c++ <<'SOURCE'
  #include "sub.h++"
  #include "buried.h++"
int sub(void) { return buried(); }
SOURCE

        cat >src/top.c++ <<'SOURCE'
  #include "sub.h++"
  #include <cstdio>
int main(void) { printf("%d\n", sub()); return 0; }
SOURCE
    )
}

##############################################################################
# A subproject of a project that asked for it                                #
##############################################################################
tree on on
(cd on && $PTEST_BINARY $PCONFIGURE_ARGS --verbose && make $MAKE_ARGS) \
    > on/build.log 2>&1
cat on/build.log

test "$(./on/bin/top)" = "4"

# The subproject's own Makefile is the one that has to have changed:
# it is where its sources live, and it is written by the same run.
grep -q "^include .*\.d$" on/sub/obj/Makefile.sub

# And what it no longer says is the point.  A compile rule in the
# Makefile is a dependency worked out at configure time; there should
# not be one, for the source the Configfile named or for the one it
# didn't.
if grep -q "obj/src/sub.c++.*\.o:" on/sub/obj/Makefile.sub
then
    exit 1
fi
if grep -q "obj/src/buried.c++" on/sub/obj/Makefile.sub
then
    exit 1
fi

# Two sources reached, which is the one named plus the one behind the
# header.  A walk that found nothing would satisfy every check above.
test "$(find on/sub/obj -name '*.o' | wc -l)" -eq 2

##############################################################################
# An include added afterwards                                                #
##############################################################################
# The whole promise, and the thing that fails without the inheritance:
# a source appears behind a header that a subproject source has just
# started reading, and a plain "make" compiles and links it.  Nobody
# runs pconfigure here.
cat >on/sub/src/late.h++ <<'SOURCE'
int late(void);
SOURCE

cat >on/sub/src/late.c++ <<'SOURCE'
int late(void) { return 30; }
SOURCE

cat >on/sub/src/sub.c++ <<'SOURCE'
  #include "sub.h++"
  #include "buried.h++"
  #include "late.h++"
int sub(void) { return buried() + late(); }
SOURCE

(cd on && make $MAKE_ARGS) > on/second.log 2>&1
cat on/second.log

test "$(./on/bin/top)" = "34"
test "$(find on/sub/obj -name '*.o' | wc -l)" -eq 3

##############################################################################
# A subproject that said no                                                  #
##############################################################################
# Inherited rather than imposed: a tree with its own line still wins,
# the way it does with a PREFIX.  Its Makefile keeps the compile rules
# that say what pconfigure worked out, and its parent's are still
# written the other way.
tree split on off
(cd split && $PTEST_BINARY $PCONFIGURE_ARGS --verbose && make $MAKE_ARGS) \
    > split/build.log 2>&1
cat split/build.log

test "$(./split/bin/top)" = "4"

grep -q "obj/src/sub.c++.*\.o:" split/sub/obj/Makefile.sub
grep -q "obj/src/buried.c++" split/sub/obj/Makefile.sub
if grep -q "^include .*\.d$" split/sub/obj/Makefile.sub
then
    exit 1
fi

# The parent still asked for it, and still gets it.
grep -q "^include .*\.d$" split/Makefile

exit 0
