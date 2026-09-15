#include "harness_start.bash"
#pconfigure TESTDEPS += bin/pdeps

# A dependency fragment is not the source it describes.  It is what one
# version of pdeps made of that source, and for as long as this project
# has had AUTORECONFIGURE there has been nothing anywhere saying so: the
# rules that build a ".d" named the source and the context file beside
# it, and that was all.  So a pdeps that had learned to see something
# new -- a directive it used to skip, a path it used to get wrong --
# changed nothing until somebody happened to touch every source in the
# tree, and what a build did in the meantime was link objects compiled
# against a dependency graph nobody was maintaining any more.
#
# It survived as long as it did by accident.  The path pdeps was found
# at goes into the context file, and the context file is a prerequisite,
# so a pconfigure that was moved, renamed or installed somewhere else
# did invalidate every fragment.  The case that slipped through is a
# pconfigure rebuilt where it stood -- which is the case a project
# vendoring pconfigure as a submodule is in every single time anybody
# edits it, and is where this was found.
#
# There are two halves to it, because there are two places a fragment's
# rule gets written.  pconfigure writes the rule for a source a
# Configfile named; pdeps writes the rule for a source it found sitting
# behind a header, which pconfigure was never told about and cannot
# write a rule for.  Fixing either one alone leaves half the tree
# stale, so this test keeps a source of each shape and asserts both.

here="$(pwd)"

##############################################################################
# A pdeps this test is allowed to touch                                      #
##############################################################################
# Not the one the build is using.  Bumping the mtime of the real
# bin/pdeps from inside a test perturbs the build that is running the
# test, which is a mess that shows up somewhere else entirely and long
# afterwards, so the tool gets copied in here and everything below
# points at the copy.
#
# Both directories, though.  The tools are linked against
# libpconfigure with an RPATH of "@loader_path/../lib", so a bin/
# copied on its own is a binary that links and cannot load -- which
# fails as an empty fragment rather than as an error, and an empty
# fragment is exactly what this test would otherwise be asserting the
# absence of.
cp -R "$(dirname "$PTEST_BINARY")" bin
cp -R "$(dirname "$PTEST_BINARY")/../lib" lib

##############################################################################
# A project with one source of each shape                                    #
##############################################################################
# AUTORECONFIGURE, because that is the mode the fragments exist in: it
# is what moves "what does this source depend on" out of pconfigure and
# into the build, and without it there are no ".d" files to go stale.
mkdir -p src

cat >Configfile <<EOF
AUTORECONFIGURE  = true

LANGUAGES       += c++

BINARIES        += app
SOURCES         += app.c++
EOF

# The source the Configfile names, whose rule pconfigure writes.
cat >src/app.c++ <<'EOF'
  #include "helper.h++"
int main(void) { return helper(); }
EOF

# And the source nobody named, which the walk reaches through the
# header and whose rule pdeps writes into app's fragment.
cat >src/helper.h++ <<'EOF'
int helper(void);
EOF

cat >src/helper.c++ <<'EOF'
  #include "helper.h++"
int helper(void) { return 0; }
EOF

##############################################################################
# A build, and then a build that does nothing                                #
##############################################################################
./bin/pconfigure
make $MAKE_ARGS > first.out 2>&1
cat first.out

# One fragment apiece, found by glob because what a fragment is called
# is a hash of the options it was compiled under rather than anything a
# test should be spelling out.  Both of them exist, which is the shape
# this test needs: the named source and the one behind the header.
test "$(ls obj/src/app.c++/*-static.d | wc -l)" -eq 1
test "$(ls obj/src/helper.c++/*-static.d | wc -l)" -eq 1

# Which is what makes everything below mean something: once a "nothing
# to be done" is the ordinary answer, a build that says anything at all
# has been provoked into it.
make $MAKE_ARGS > settled.out 2>&1
cat settled.out
grep -q "Nothing to be done" settled.out

##############################################################################
# What the rules say, and how they spell it                                  #
##############################################################################
# Checked as text as well as behaviourally, because the spelling is the
# part that is dangerous to get wrong and the part that looks most like
# something worth tidying.  pconfigure names pdeps by the absolute path
# it resolved the tool to.  A tree that vendors pconfigure also has a
# rule for that same binary under a relative in-tree path, and make does
# not treat the two spellings as the same file -- which is the point.
# As an absolute path this is a prerequisite with no rule behind it: a
# timestamp, and nothing make will try to produce.
#
# Spell it relatively instead, so that make can "helpfully" build the
# tool for you, and the build stops working.  Fragments are included
# makefiles, so make goes looking for that rule during the phase where
# it is still remaking what it is about to read -- before it has read
# the fragments that say which objects pdeps is built out of -- and
# links it out of none of them.
#
# Which is why the leading "/" in front of the tool is load-bearing
# rather than decoration.  A pattern of ".*/bin/pdeps" is a pattern
# that "src/pconfigure/bin/pdeps" satisfies, and that is the exact
# spelling the paragraph above is about: the assertion would have gone
# on passing over the tree it exists to rule out.  Asking for an
# absolute path is asking the question that was meant.
#
# "[^ )]*" rather than ".*" between that "/" and the tool, because a
# rule line holds more than one prerequisite and ".*" is happy to walk
# straight across a ")" and into the next "$(wildcard" to find what it
# was asked for.  A line naming some other prerequisite absolutely and
# pdeps relatively would satisfy the loose spelling -- the leading "/"
# would be matched against a different prerequisite entirely, and the
# one under test would go unexamined.  Stopping the match at a space or
# a bracket keeps the "/" and the tool inside the same term.
#
# And keep the pattern in single quotes.  In double quotes the shell
# reads "$(wildcard ...)" as a command substitution and hands grep a
# pattern with the middle cut out of it, which is how two assertions in
# this suite came to pass against anything at all.
grep -q '\.d: .*\$(wildcard /[^ )]*/bin/pdeps)$' Makefile
grep -q '^obj/src/helper\.c++/.*\.d:.*\$(wildcard /[^ )]*/bin/pdeps)$' obj/src/app.c++/*-static.d

##############################################################################
# A pdeps that changed                                                       #
##############################################################################
# Both fragments re-derive, and the second assertion is the whole
# reason this test is longer than one line: helper.c++'s rule was
# written by pdeps rather than by pconfigure, so it goes on being stale
# if only the pconfigure half of this was fixed.
sleep 1
touch bin/pdeps

make $MAKE_ARGS > touched.out 2>&1
cat touched.out

grep -q "DEPS	app.c++" touched.out
grep -q "DEPS	helper.c++" touched.out

# And nothing was compiled over it.  That is what makes this cheap
# enough to do at all: a fragment is not a prerequisite of the object
# it describes, so re-deriving one costs a pdeps run and rebuilds
# something only if what it says actually changed -- which is precisely
# when a rebuild is the right answer.  If that ever stops being true
# this stops being a free correctness fix and becomes an expensive one,
# so it is asserted rather than assumed.
if grep -q "C++" touched.out
then
    exit 1
fi

##############################################################################
# A pdeps that is not there at all                                           #
##############################################################################
# "make clean" deletes the vendored pconfigure and its tools, because
# the build produced them.  Every fragment in the tree is still
# perfectly current at that moment, and what must happen next is
# nothing.
#
# That is what "$(wildcard)" around the path buys, and it is the other
# half of the spelling this test is defending: a bare path to a file
# that is not there is "No rule to make target", and a tree that says
# that is a tree nobody can build out of until they work out that the
# answer is to build the thing the build just deleted.
rm -f bin/pdeps

make $MAKE_ARGS > gone.out 2>&1
cat gone.out
grep -q "Nothing to be done" gone.out

exit 0
