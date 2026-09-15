#include "harness_start.bash"

# A subproject's Makefile is written to work both ways, and so is the
# build that comes out of it: the parent includes the file and every
# path in it goes through a variable naming the subproject, while a
# build run where the file sits leaves that variable empty and every
# path means something in the subproject's own directory.
#
# The rules get that right.  What did not was the context file pdeps
# reads, which is written once, by a pconfigure standing at the top of
# the tree, with the variable already expanded -- so the same file
# told pdeps a different thing than the rule invoking it, and only
# from inside the subproject, and only when a fragment actually needed
# rebuilding.  make made the directory the rule named and pdeps wrote
# into the one the context named, one project deeper.
#
# Nothing said so.  The fragment landed in a directory nothing reads,
# and what it said was that the source had been deleted -- because the
# source had been looked for one directory too high.  Had it landed
# where the rule wanted it, make would have been told this project has
# no sources at all.
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
LANGUAGES += c
HEADERS   += subbin.h

BINARIES  += subbin
SOURCES   += subbin.c
EOF

cat >sub/include/subbin.h <<'EOF'
#define SUBBIN_RETURN 0
EOF

cat >sub/src/subbin.c <<'EOF'
#include <subbin.h>
int main(void) { return SUBBIN_RETURN; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
./bin/top
./sub/bin/subbin

# What the parent built, which is the spelling the context file was
# frozen with.
test -d sub/obj/src/subbin.c
ls sub/obj/src/subbin.c/*.d

##############################################################################
# Building it from inside, with something that has to be rebuilt              #
##############################################################################
# The build from the top left every fragment up to date, so a build
# from inside that asks for nothing is a build that never runs pdeps
# and never finds out which spelling it believes.  Editing the header
# is what makes it run: the fragment naming that header is older than
# the header now.
echo "#define SUBBIN_OTHER 1" >> sub/include/subbin.h

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
if grep -q "There is no such file today" sub/obj/src/subbin.c/*.d
then
    cat sub/obj/src/subbin.c/*.d
    exit 1
fi
grep -q "subbin.h" sub/obj/src/subbin.c/*.d

##############################################################################
# ... and the parent still builds                                            #
##############################################################################
# The fragment is one file read by both builds, so a fragment rewritten
# from inside has to be one the parent can read.  Rebuilt from up here
# it has the variable back on the front of every path.
make $MAKE_ARGS
./bin/top
./sub/bin/subbin

test ! -e sub/sub

exit 0
