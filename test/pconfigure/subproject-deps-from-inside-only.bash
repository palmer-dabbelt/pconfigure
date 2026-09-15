#include "harness_start.bash"

# The other way a build gets run from inside a subproject: not after a
# build from the top, but instead of one.  A tree gets configured from
# the top and never built there, and then somebody works on one
# subproject, configures it where it sits, and builds only that.
#
# Every fragment in the subproject is written by that build rather
# than rewritten by it, so there is nothing already on disk to make
# the answer come out right by accident.  It is the same question the
# other two tests ask with the order changed, and the order is what
# decides whether a fragment's spelling is being produced or merely
# preserved.
mkdir -p src sub/src

cat >Configfile <<EOF
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
# Said again down here rather than only inherited from above, because
# the build this is about is configured down here and a configure that
# ran here has no parent to inherit it from.
AUTORECONFIGURE = true

LANGUAGES += c

BINARIES  += subbin
SOURCES   += subbin.c
EOF

# Named by no Configfile: the fragment is the only thing that says
# this source is in the build, so a build that links it is a build
# whose fragments were written correctly from down here.
cat >sub/src/buried.h <<'EOF'
int buried(void);
EOF

cat >sub/src/buried.c <<'EOF'
int buried(void) { return 7; }
EOF

cat >sub/src/subbin.c <<'EOF'
#include "buried.h"
int main(void) { return buried() == 7 ? 0 : 1; }
EOF

# Configured from the top, which is where pconfigure runs.  Nothing is
# built here at all: the object directory exists because the context
# file pdeps reads lives in it, and it is written by configuring
# rather than by building, but nothing has been compiled or linked and
# no fragment has been written.
$PTEST_BINARY $PCONFIGURE_ARGS

test ! -e sub/bin/subbin
test -z "$(find sub/obj -name '*.d' -print -quit)"

##############################################################################
# Configured and built only from inside                                      #
##############################################################################
(cd sub && $PTEST_BINARY $PCONFIGURE_ARGS)
(cd sub && make $MAKE_ARGS && ./bin/subbin)

# The walk happened from down here and found the buried source, which
# is what the binary returning 7 says: a fragment that had failed to
# name it would have left the link short a symbol rather than quietly
# building something that works.
test -e sub/bin/subbin

# And not into a directory named after the subproject inside it.
test ! -e sub/sub
test ! -e sub/obj/sub

if grep -q "There is no such file today" sub/obj/src/subbin.c/*.d
then
    cat sub/obj/src/subbin.c/*.d
    exit 1
fi

# Written from where the build that wrote it was standing, with
# nothing on the front, because that is the spelling that means the
# right file from there.  A fragment is one build's answer about one
# source, and the build that wrote this one was standing in the
# subproject.
test "$(ls sub/obj/src/subbin.c/*.d | wc -l)" -eq 1
from_inside="$(echo sub/obj/src/subbin.c/*.d)"
grep -q "^include obj/src/buried.c/" "$from_inside"

##############################################################################
# ... and now the top, which has never been built                            #
##############################################################################
# It has no fragment of its own to read: the only one on disk belongs
# to the build from inside, and says paths that mean nothing from up
# here.  So it writes one, which is what the name on the end of a
# context file is for.
make $MAKE_ARGS
./bin/top
./sub/bin/subbin

test "$(ls sub/obj/src/subbin.c/*.d | wc -l)" -eq 2
from_the_top="$(ls sub/obj/src/subbin.c/*.d | grep -v -x -F "$from_inside")"
cat "$from_the_top"
grep -q "^include \$(pconfigure_subdir_sub)obj/src/buried.c/" "$from_the_top"

# And it left the other one alone.  The two builds share the objects
# they compile, which is the point of them describing one tree; what
# they must not share is the file that says where those objects came
# from, because each of them says it from somewhere else.
grep -q "^include obj/src/buried.c/" "$from_inside"

exit 0
