#include "harness_start.bash"
#pconfigure TESTDEPS += bin/pdeps

# pdeps on its own, with a context file written by hand rather than by
# pconfigure.  What it produces is a piece of Makefile, so what is
# checked here is both what the file says and what make does with it:
# the second of those is the part that matters, since the whole design
# is that the walk pconfigure would have done happens by make reading
# one of these after another.
#
# The compiler and the linker are stubs.  Nothing here is about
# compiling anything, and a test that shells out to a real toolchain
# to prove a string was written correctly is a test that fails for
# reasons it wasn't asking about.

# The pdeps that goes with the pconfigure being tested, which is the
# one sitting next to it: that is where pconfigure looks for its own
# tools, so it is where this test has to look too.
pdeps="$(dirname "$PTEST_BINARY")/pdeps"

mkdir -p src stub

cat >stub/cc <<'STUB'
#!/bin/bash
while [ $# -gt 0 ]
do
    case "$1" in -o) shift; out="$1" ;; esac
    shift
done
mkdir -p "$(dirname "$out")"
echo "$out" > "$out"
STUB

cat >stub/ld <<'STUB'
#!/bin/bash
while [ $# -gt 0 ]
do
    case "$1" in -o) shift; out="$1" ;; *.o) objs="$objs $1" ;; esac
    shift
done
mkdir -p "$(dirname "$out")"
echo "$objs" > "$out"
STUB

chmod +x stub/cc stub/ld

# A source that reads a header, a header with a source of its own
# behind it, and a second header with nothing behind it.  That is the
# whole of what the walk has to tell apart.
cat >src/app.c++ <<'SOURCE'
  #include "helper.h++"
  #include "plain.h++"
SOURCE

cat >src/helper.h++ <<'SOURCE'
int helper(void);
SOURCE

cat >src/helper.c++ <<'SOURCE'
int helper(void) { return 0; }
SOURCE

cat >src/plain.h++ <<'SOURCE'
static const int plain = 1;
SOURCE

context() {
    mkdir -p obj/bin/app/L
    cat >obj/bin/app/L/deps-context-OPTS <<EOF
src-prefix src/
obj-prefix obj/src/
obj-suffix /OPTS-static.o
dep-prefix obj/src/
dep-suffix /OPTS-L-static.d
compiler $(pwd)/stub/cc
pretty C++
pdeps $pdeps
quiet true
autodeps $1
link obj/bin/app/L/local
opt -Isrc
EOF
}

##############################################################################
# What one source turns into                                                 #
##############################################################################
context true
$pdeps --context obj/bin/app/L/deps-context-OPTS --source app.c++

d="obj/src/app.c++/OPTS-L-static.d"
cat $d

# The object this source becomes, and the link it belongs to.
grep -q "^obj/bin/app/L/local: obj/src/app.c++/OPTS-static.o$" $d

# Both headers are prerequisites of the object, which is what makes
# make rebuild it when one of them changes.
grep -q "^obj/src/app.c++/OPTS-static.o: src/app.c++ src/helper.h++ src/plain.h++$" $d

# And of this file, which is what makes make ask the question again
# when a header that might have grown an include of its own changes.
grep -q "^$d: src/app.c++ src/helper.h++ src/plain.h++$" $d

# A header that has been deleted since is a rebuild rather than a
# build that stops, so each one gets a rule with nothing in it.
grep -q "^src/helper.h++:$" $d
grep -q "^src/plain.h++:$" $d

# The source behind the first header is pulled in by including the
# same sort of file written about it; the second header has no source
# behind it and gets nothing.
grep -q "^include obj/src/helper.c++/OPTS-L-static.d$" $d
if grep -q "plain.c++" $d
then
    exit 1
fi

# The compile rule is written once per object rather than once per
# target that wants it, since two targets sharing an object would
# otherwise be two recipes for one file.
grep -q "^ifndef __pconfigure__object-obj/src/app.c++/OPTS-static.o$" $d
grep -q "^	@echo \"C++	app.c++\"$" $d

##############################################################################
# What make does with it                                                     #
##############################################################################
# The recursion is the point: nothing above named "helper.c++", and
# it has to get compiled and linked anyway.
cat >Makefile <<EOF
.PHONY: all
all: obj/bin/app/L/local

ifndef __pconfigure__deps-$d
__pconfigure__deps-$d := 1
$d: src/app.c++ obj/bin/app/L/deps-context-OPTS
	@mkdir -p \$(dir \$@)
	@$pdeps --context obj/bin/app/L/deps-context-OPTS --source app.c++
include $d
endif

obj/bin/app/L/local:
	@mkdir -p \$(dir \$@)
	@$(pwd)/stub/ld -o \$@ \$(filter %.o,\$^)
EOF

rm -rf obj/src
make $MAKE_ARGS

# Both objects were built, and the one nobody named came first: that
# is the order pconfigure walks in, and it has to be the order make
# arrives at too.
test "$(cat obj/bin/app/L/local)" = " obj/src/helper.c++/OPTS-static.o obj/src/app.c++/OPTS-static.o"

# Asked again with nothing changed, there is nothing to do.  A build
# that re-derives its dependencies every time is a build that rebuilds
# every time.
make $MAKE_ARGS > second.out 2>&1
cat second.out
grep -q "Nothing to be done" second.out

##############################################################################
# A source that grew an include                                              #
##############################################################################
# Which is the whole feature: nobody ran pconfigure between these two
# makes, and the new source is compiled and linked anyway.
cat >src/late.h++ <<'SOURCE'
int late(void);
SOURCE

cat >src/late.c++ <<'SOURCE'
int late(void) { return 0; }
SOURCE

sleep 1
cat >src/app.c++ <<'SOURCE'
  #include "helper.h++"
  #include "plain.h++"
  #include "late.h++"
SOURCE

make $MAKE_ARGS
test -e obj/src/late.c++/OPTS-static.o
grep -q "late.c++" obj/bin/app/L/local

##############################################################################
# A header that went away                                                    #
##############################################################################
# make has no rule for a prerequisite that isn't there, and stopping
# is the wrong answer: a header being deleted is an ordinary edit, and
# what should follow is a rebuild of whatever used to read it.
sleep 1
rm src/plain.h++
cat >src/app.c++ <<'SOURCE'
  #include "helper.h++"
  #include "late.h++"
SOURCE

make $MAKE_ARGS
if grep -q "plain.h++" obj/src/app.c++/OPTS-L-static.d
then
    exit 1
fi

##############################################################################
# A source that went away                                                    #
##############################################################################
# Deleting a source leaves the fragment written about it sitting in the
# object directory, and nothing that reads it has changed: what pulled
# it in was a header, and the header is still there.  So make reads a
# fragment naming a file that is not there, and the one thing it must
# not do is stop -- or, worse, decide the fragment needs remaking,
# remake it, start over, and never finish.
sleep 1
rm src/helper.c++

timeout 60 make $MAKE_ARGS > gone.out 2>&1 || { cat gone.out; exit 1; }
cat gone.out

# What the stale fragment says now is nothing at all, rather than a
# rule for an object built from a file that does not exist.
if grep -q "^obj/src/helper.c++" obj/src/helper.c++/OPTS-L-static.d
then
    exit 1
fi

# The link is not redone on its own: make has no idea that a
# prerequisite went away, only that the ones still named are older
# than what was built from them.  That is true of a Makefile
# pconfigure wrote the objects into as well, so it is the behaviour
# being kept rather than one being introduced.  Anything that touches
# the source settles it.
sleep 1
touch src/app.c++
make $MAKE_ARGS
if grep -q "helper.c++" obj/bin/app/L/local
then
    exit 1
fi

# And when the source comes back it is a prerequisite again, which is
# the half a plain "does it exist" check would have got wrong.
cat >src/helper.c++ <<'SOURCE'
int helper(void) { return 0; }
SOURCE

sleep 1
touch src/app.c++
make $MAKE_ARGS
grep -q "helper.c++" obj/bin/app/L/local

##############################################################################
# Two sources that include each other's headers                              #
##############################################################################
# The walk goes round in a circle, and an "include" that went round it
# twice is make reading Makefiles until it runs out of memory.
cat >src/app.c++ <<'SOURCE'
  #include "ring.h++"
SOURCE

cat >src/ring.h++ <<'SOURCE'
int ring(void);
SOURCE

cat >src/ring.c++ <<'SOURCE'
  #include "app.h++"
int ring(void) { return 0; }
SOURCE

cat >src/app.h++ <<'SOURCE'
int app(void);
SOURCE

sleep 1
rm -rf obj/src
make $MAKE_ARGS
grep -q "ring.c++" obj/bin/app/L/local
grep -q "app.c++" obj/bin/app/L/local

##############################################################################
# With the walk turned off                                                   #
##############################################################################
# AUTODEPS = false means the sources behind the headers are somebody
# else's problem.  The headers are still prerequisites, because a
# target that doesn't want them linked still wants to be rebuilt when
# one of them changes.
context false
rm -rf obj/src
$pdeps --context obj/bin/app/L/deps-context-OPTS --source app.c++
cat $d

grep -q "^obj/src/app.c++/OPTS-static.o: src/app.c++ src/ring.h++$" $d
if grep -q "^include " $d
then
    exit 1
fi

exit 0
