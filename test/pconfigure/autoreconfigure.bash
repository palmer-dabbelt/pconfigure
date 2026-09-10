#include "harness_start.bash"
#pconfigure TESTDEPS += bin/pdeps

# AUTORECONFIGURE moves the question "what does this source depend on"
# out of pconfigure and into the build.  What pconfigure writes stops
# being a list of objects and becomes a list of the sources a
# Configfile named; everything below that -- the compile rules, the
# headers, the sources found behind those headers -- is written during
# the build, by pdeps, into pieces of Makefile that make includes.
#
# The thing being checked is that this changes nothing except when the
# work happens.  The same project configured both ways has to build
# the same objects, from the same command lines, in the same order.

# The same sources either way, laid out so the walk has somewhere to
# go: app reads a header whose source reads another header, and a
# second source shares the first header with it.
project() {
    mkdir -p "$1/src"
    (
        cd "$1"
        {
            test "$2" = "on" && echo "AUTORECONFIGURE  = true"
            cat <<'CONFIGFILE'
LANGUAGES       += c++

BINARIES        += app
SOURCES         += app.c++
SOURCES         += second.c++
SOURCES         += helper.c++
CONFIGFILE
        } > Configfile

        cat >src/app.c++ <<'SOURCE'
  #include "helper.h++"
  #include <cstdio>
int main(void) { printf("%d\n", helper() + 10); return 0; }
SOURCE

        cat >src/helper.h++ <<'SOURCE'
  #include "deep.h++"
int helper(void);
SOURCE

        cat >src/helper.c++ <<'SOURCE'
  #include "helper.h++"
int helper(void) { return deep(); }
SOURCE

        cat >src/deep.h++ <<'SOURCE'
int deep(void);
SOURCE

        cat >src/deep.c++ <<'SOURCE'
int deep(void) { return 5; }
SOURCE

        cat >src/second.c++ <<'SOURCE'
  #include "helper.h++"
int second(void) { return helper(); }
SOURCE
    )
}

# The objects handed to the linker, in the order they were handed
# over.  "--verbose" is what puts the command in the log to be read.
linked() {
    grep -oE ' -oobj/bin/app/[0-9]+/local .*' "$1/build.log" \
        | head -1 | tr ' ' '\n' | grep '\.o$'
}

##############################################################################
# The same project, configured both ways                                     #
##############################################################################
project off off
project on  on

for d in off on
do
    (cd $d && $PTEST_BINARY $PCONFIGURE_ARGS --verbose && make $MAKE_ARGS) \
        > $d/build.log 2>&1
    cat $d/build.log
done

# The whole claim, in one comparison: same objects, same order, same
# names -- and the names have the compile options hashed into them, so
# same name is also same command line.
linked off > off.objects
linked on  > on.objects
cat off.objects
cmp off.objects on.objects

# Four of them, which is the three the Configfile named plus the one
# found only behind a header.  A comparison of two empty files would
# pass and say nothing.
test "$(wc -l < off.objects)" -eq 4

# "helper.c++" is named by the Configfile and also sits behind a
# header that "app.c++" reads, so pconfigure and pdeps both have
# reason to write a rule for its fragment.  Two recipes for one file
# is something make resolves by picking one and mentioning it in a
# warning, which is the sort of thing a build says once and nobody
# ever reads.
if grep -q "overriding recipe" on/build.log
then
    exit 1
fi

# And the programs agree, which is the only test of the objects that
# doesn't go through pconfigure at all.
test "$(./off/bin/app)" = "$(./on/bin/app)"
test "$(./on/bin/app)" = "15"

##############################################################################
# What the two Makefiles say                                                  #
##############################################################################
# The one that works its dependencies out during the build says
# nothing about the sources it was never told about, and nothing about
# any object: that is the point, and it is what makes an edit to an
# "#include" something the build can notice.
grep -q "obj/src/deep.c++" off/Makefile
if grep -q "obj/src/deep.c++" on/Makefile
then
    exit 1
fi
if grep -q "obj/src/app.c++.*\.o:" on/Makefile
then
    exit 1
fi

# What it says instead is: here is the fragment for a source you named,
# here is how to build it, and the link takes whatever turns up.
grep -q "^include obj/src/app.c++/[0-9]*-[0-9]*-static\.d$" on/Makefile

# A fragment sits beside the object it describes rather than in a
# directory of its own, which is where somebody looking for one would
# look.  Checked by name and by there being no such directory, because
# a layout is the sort of thing that comes back.
test "$(find on/obj -type d -name deps | wc -l)" -eq 0
test "$(find on/obj/src/app.c++ -name '*-static.d' | wc -l)" -eq 1
test "$(find on/obj/src/app.c++ -name '*-static.o' | wc -l)" -eq 1
grep -q "echo \"DEPS	app.c++\"" on/Makefile
grep -q '\$(filter %.o,\$^)' on/Makefile

##############################################################################
# A second make                                                              #
##############################################################################
# A build that works out its dependencies every time is a build that
# rebuilds every time.
(cd on && make $MAKE_ARGS) > second.out 2>&1
cat second.out
grep -q "Nothing to be done" second.out

##############################################################################
# A source that grew an include                                              #
##############################################################################
# The whole feature.  Nobody runs pconfigure between these two makes,
# and the source behind the new header is compiled and linked anyway.
cat >on/src/late.h++ <<'SOURCE'
int late(void);
SOURCE

cat >on/src/late.c++ <<'SOURCE'
int late(void) { return 100; }
SOURCE

sleep 1
cat >on/src/app.c++ <<'SOURCE'
  #include "helper.h++"
  #include "late.h++"
  #include <cstdio>
int main(void) { printf("%d\n", helper() + late()); return 0; }
SOURCE

(cd on && make $MAKE_ARGS) > late.out 2>&1
cat late.out
test "$(./on/bin/app)" = "105"

# The same edit, made to the project that worked its dependencies out
# when it was configured, does not build: nothing there knows the new
# header exists, and that is the behaviour AUTORECONFIGURE is for.
cp on/src/late.h++ on/src/late.c++ off/src/
sleep 1
cp on/src/app.c++ off/src/app.c++

if (cd off && make $MAKE_ARGS) > offlate.out 2>&1
then
    echo "the configure-time build linked a source nobody told it about" >&2
    exit 1
fi
cat offlate.out

##############################################################################
# A header that went away                                                    #
##############################################################################
# make has no rule for a prerequisite that is not there, and a header
# being deleted is an ordinary edit rather than a reason to stop.
sleep 1
rm on/src/late.h++ on/src/late.c++
cat >on/src/app.c++ <<'SOURCE'
  #include "helper.h++"
  #include <cstdio>
int main(void) { printf("%d\n", helper() + 10); return 0; }
SOURCE

(cd on && make $MAKE_ARGS)
test "$(./on/bin/app)" = "15"

##############################################################################
# Collecting the object cache                                                #
##############################################################################
# "make cache-clean" keeps what the build still knows how to make.
# Most of that is written down in the fragments rather than in the
# Makefile here, and throwing those away would take the context files
# pdeps reads with them -- which is a build that stops on a missing
# file nothing has a rule for.
(cd on && make $MAKE_ARGS cache-clean)
(cd on && make $MAKE_ARGS) > cacheclean.out 2>&1
cat cacheclean.out
grep -q "Nothing to be done" cacheclean.out

##############################################################################
# Cleaning                                                                   #
##############################################################################
# "make clean" takes the fragments along with the objects -- all of
# them, the ones pconfigure named and the ones pdeps found behind a
# header, since an object directory holding half of one kind of file
# is a thing nobody could explain.  What it leaves is what pconfigure
# wrote, which is the context files, the same way it leaves the
# Makefile.
(cd on && make $MAKE_ARGS clean)
test "$(find on/obj -name '*.d' | wc -l)" -eq 0
test "$(find on/obj -name '*.o' | wc -l)" -eq 0
test "$(find on/obj -name 'deps-context-*' | wc -l)" -ne 0

(cd on && make $MAKE_ARGS)
test "$(./on/bin/app)" = "15"

##############################################################################
# One source compiled two ways                                               #
##############################################################################
# The context file pdeps reads is written per set of compile options
# rather than per source, because that is the granularity the object
# names already have.  Two targets that compile the same source with
# different options are two objects, two walks and two context files,
# and getting that wrong would link one flavour into both programs --
# which is a mistake that builds, runs, and prints the wrong number.
mkdir -p flavours/src
cd flavours

cat >Configfile <<'CONFIGFILE'
AUTORECONFIGURE  = true
LANGUAGES       += c++

BINARIES        += one
COMPILEOPTS     += -DFLAVOUR=1
SOURCES         += main.c++

BINARIES        += two
COMPILEOPTS     += -DFLAVOUR=2
SOURCES         += main.c++
CONFIGFILE

cat >src/main.c++ <<'SOURCE'
  #include "shared.h++"
  #include <cstdio>
int main(void) { printf("%d\n", FLAVOUR * shared()); return 0; }
SOURCE

cat >src/shared.h++ <<'SOURCE'
int shared(void);
SOURCE

cat >src/shared.c++ <<'SOURCE'
int shared(void) { return 10; }
SOURCE

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

test "$(./bin/one)" = "10"
test "$(./bin/two)" = "20"

# Four objects: both sources, once per set of options.  The source
# behind the header is walked twice because the options it inherits
# differ, which is what pconfigure does with it too.
test "$(find obj -name '*.o' | wc -l)" -eq 4
test "$(find obj -name 'deps-context-*' | wc -l)" -eq 2

cd ..

##############################################################################
# A source two targets compile the same way                                  #
##############################################################################
# The other half of that, and the one where the fragments and the
# objects stop agreeing about how many there are.  Compiled identically,
# so both targets share one object -- but a fragment says which links
# its object goes on, so there are two of those.  Nothing in the
# object's name distinguishes them, which is the whole reason a
# fragment's name carries the link as well.
mkdir -p shared/src
cd shared

cat >Configfile <<'CONFIGFILE'
AUTORECONFIGURE  = true

LANGUAGES       += c++

BINARIES        += first
SOURCES         += main.c++

BINARIES        += second
SOURCES         += main.c++
CONFIGFILE

cat >src/main.c++ <<'SOURCE'
  #include "common.h++"
  #include <cstdio>
int main(void) { printf("%d\n", common()); return 0; }
SOURCE

cat >src/common.h++ <<'SOURCE'
int common(void);
SOURCE

cat >src/common.c++ <<'SOURCE'
int common(void) { return 7; }
SOURCE

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS > build.log 2>&1
cat build.log

test "$(./bin/first)" = "7"
test "$(./bin/second)" = "7"

# One object per source, shared by both links.
test "$(find obj -name '*.o' | wc -l)" -eq 2

# Two fragments per source, one per link, sitting beside that one
# object.  Without the link in the name these would be one file with
# two recipes, which pconfigure refuses outright rather than writing.
test "$(find obj/src/main.c++ -name '*-static.d' | wc -l)" -eq 2
test "$(find obj/src/common.c++ -name '*-static.d' | wc -l)" -eq 2

if grep -q "overriding recipe" build.log
then
    exit 1
fi

cd ..

exit 0
