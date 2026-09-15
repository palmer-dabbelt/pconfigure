#include "harness_start.bash"

# A subproject is described twice.  Once by the run at the top of the
# tree, whose Makefile goes into the subproject's object directory and
# spells every path through a variable naming the subproject; and once
# by a run standing in the subproject, whose Makefile sits at the top
# of it and spells every path bare.
#
# The fragments pdeps writes belong to one of those builds or the
# other, and each has to say which.  A fragment written from the top is
# read by the build from the top and by nothing else, and the same
# holds the other way round: a fragment they shared would be one build
# reading a set of paths measured from a place it is not standing.
#
# What did not get that right was the context file pdeps reads.  It
# says where to write and what to write about, in paths, and there was
# one of them serving both builds -- so it told pdeps a different
# thing than the rule invoking it, and only from inside the
# subproject, and only when a fragment actually needed rebuilding.
# make made the directory the rule named and pdeps wrote into the one
# the context named, one project deeper, saying the source had been
# deleted because it had looked for it one directory too high.
mkdir -p src sub/src sub/include

cat >Configfile <<EOF
# The fragments this is about only exist under AUTORECONFIGURE: it is
# what moves "which headers does this source read" out of pconfigure
# and into make, one source at a time, which is what puts pdeps in the
# build at all.  A SUBPROJECTS inherits it.
AUTORECONFIGURE = true

LANGUAGES   += c
SUBPROJECTS += sub

BINARIES    += top
SOURCES     += top.c
EOF

cat >src/top.c <<'EOF'
int main(void) { return 0; }
EOF

cat >sub/Configfile <<EOF
# Said again down here, rather than only inherited from above.  A
# build run inside the subproject is configured inside it, and a
# configure that ran here has no parent to inherit anything from -- so
# without this the build from inside would have no fragments at all
# and there would be nothing to compare.
AUTORECONFIGURE = true

LANGUAGES += c
HEADERS   += subbin.h

BINARIES  += subbin
SOURCES   += subbin.c
EOF

cat >sub/include/subbin.h <<'EOF'
#define SUBBIN_BASE 0
EOF

# A header with a source behind it, which no Configfile mentions: the
# fragment is what says that source is part of the build at all.  This
# is the piece that makes the test able to fail.  A subproject whose
# sources are all named in a Configfile produces fragments full of
# rules for targets the parent's build never asks for, and a path
# spelled wrongly in one of those is a rule nothing reads -- whereas
# what gets written for a source found this way is an "include" of its
# fragment, which make has to resolve to a file that is there.  Get
# that path wrong and the parent stops on "No rule to make target".
cat >sub/src/helper.h <<'EOF'
int helper(void);
EOF

cat >sub/src/helper.c <<'EOF'
int helper(void) { return 0; }
EOF

cat >sub/src/subbin.c <<'EOF'
#include <subbin.h>
#include "helper.h"
int main(void) { return helper() + SUBBIN_BASE; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
./bin/top
./sub/bin/subbin

# What the parent built, which is the spelling the context file was
# frozen with.  The source nobody named is in the build, so the
# fragment really does carry the "include" this is about.
test -d sub/obj/src/subbin.c
ls sub/obj/src/subbin.c/*.d
grep -q 'include \$(pconfigure_subdir_sub)obj/src/helper.c/' sub/obj/src/subbin.c/*.d

# Named and kept, because the whole question below is whether the
# build from inside leaves it alone.  There is exactly one fragment
# here so far, and saying so is what makes the count below mean
# something.
test "$(ls sub/obj/src/subbin.c/*.d | wc -l)" -eq 1
from_the_top="$(echo sub/obj/src/subbin.c/*.d)"
cp "$from_the_top" from-the-top.d

##############################################################################
# Configuring and building it from inside                                    #
##############################################################################
# The other way this tree gets built, and the reason the two Makefiles
# have different names: a pconfigure run down here writes the Makefile
# at the top of the subproject, and a pconfigure run at the top of the
# tree writes one into the object directory.  Both describe these same
# sources, and they describe them from different places.
#
# Editing the header is what gives the build from inside something to
# do.  The build from the top left every fragment up to date, and a
# build that asks for nothing never runs pdeps and never finds out
# which spelling it believes.
echo "#define SUBBIN_OTHER 1" >> sub/include/subbin.h

(cd sub && $PTEST_BINARY $PCONFIGURE_ARGS)
(cd sub && make $MAKE_ARGS && ./bin/subbin)

# Nothing was written into a directory named after the subproject
# inside the subproject.  That is the shape the bug had: every path
# the context file carried had the parent's name on the front, and
# from down here that name is just another directory to create.
test ! -e sub/sub

# And nothing anywhere else in the tree either, which is the same
# mistake spelled from the parent.
test ! -e sub/obj/sub

# The fragment that got rebuilt says what the source reads, rather
# than saying the source is gone.  A fragment claiming that is what
# make would have believed: a project whose sources have all been
# deleted builds nothing and links nothing, and says so as success.
if grep -q "There is no such file today" "$from_the_top"
then
    cat "$from_the_top"
    exit 1
fi
grep -q "subbin.h" "$from_the_top"

# And the build from inside wrote a fragment of its own rather than
# over the one the build from the top reads.  Which build ran last is
# not something a file on disk should be able to say: the two of them
# describe this source from different places, so a file they shared
# would be one of the two answers wearing the other's name.
test "$(ls sub/obj/src/subbin.c/*.d | wc -l)" -eq 2
if ! cmp from-the-top.d "$from_the_top"
then
    diff -u from-the-top.d "$from_the_top" || true
    exit 1
fi

# The one the build from inside wrote names its paths from down here,
# with nothing on the front -- which is the only spelling that means
# the right file there, just as the variable is the only one that
# means it from the top.
inside="$(ls sub/obj/src/subbin.c/*.d | grep -v -x -F "$from_the_top")"
cat "$inside"
grep -q "^include obj/src/helper.c/" "$inside"

##############################################################################
# ... and the parent still builds, into the right directories               #
##############################################################################
# Which is the thing that goes wrong when it doesn't.  The parent's
# fragment is older than the header now, so this rebuilds it -- and
# the context it reads to do that is the one this run wrote, rather
# than the one the run inside the subproject wrote.  Get that wrong
# and the answer is written from the wrong distance: every path in it
# is measured from a place make is not standing.
make $MAKE_ARGS
./bin/top
./sub/bin/subbin

test ! -e sub/sub

# The subproject's fragments are where the subproject is, and not in
# the parent's own object directory one level up, which is where they
# land when the two builds share the file that says where to put them.
# The parent compiles exactly one source of its own.
test -e obj/src/top.c
test ! -e obj/src/subbin.c
test ! -e obj/src/helper.c

exit 0
