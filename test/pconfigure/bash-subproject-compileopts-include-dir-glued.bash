#include "harness_start.bash"

# The glued "-Iinc" spelling of a subproject's include directory is
# the one C has always rerooted, so it is the one a BASH target in a
# subproject is most likely to be handed.  pbashc runs from the top of
# the tree, so unless pconfigure puts the subproject's directory on
# the front it searches the top's inc/ and never finds sub/inc/.
mkdir -p sub/src sub/inc

cat >Configfile <<'EOF2'
SUBPROJECTS += sub
EOF2

cat >sub/Configfile <<'EOF2'
LANGUAGES   += bash

BINARIES    += tool
COMPILEOPTS += -Iinc
SOURCES     += tool.bash
EOF2

cat >sub/src/tool.bash <<'EOF2'
#include "helper.bash"
echo tool
EOF2

cat >sub/inc/helper.bash <<'EOF2'
echo helper
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile sub/obj/Makefile.sub
make $MAKE_ARGS
test "$(./sub/bin/tool)" = "helper
tool"
