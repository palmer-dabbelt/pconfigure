#include "harness_start.bash"

# The other way a build gets run from inside a subproject: not after a
# build from the top, but instead of one.  A tree gets configured
# once, from the top, because that is the only place pconfigure runs
# -- and then somebody works on one subproject and builds only that.
#
# Every fragment in the subproject is written by that build, rather
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
# Built only from inside                                                     #
##############################################################################
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

# Written through the variable, even though the build that wrote it
# had that variable set to nothing.  This is the whole property: what
# a fragment says does not depend on where the build that wrote it was
# standing, because the next build to read it may be standing
# somewhere else.
grep -q 'include \$(pconfigure_subdir_sub)obj/src/buried.c/' sub/obj/src/subbin.c/*.d

##############################################################################
# ... and now the top, which has never been built                            #
##############################################################################
# Reading fragments that only a build from inside has ever written.
make $MAKE_ARGS
./bin/top
./sub/bin/subbin

exit 0
