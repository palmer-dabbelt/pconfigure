#include "harness_start.bash"

# A relative "-I" in a subproject's COMPILEOPTS names a directory in
# that subproject, because whoever wrote the Configfile only knew about
# their own project -- and for C it gets the subproject's directory put
# on the front so that it still means that from the top of the tree.
# pbashc runs from the top of the tree just the same, so a BASH
# target's "-I inc" needs the same rewriting: without it pbashc looked
# in the top's inc/, never found the helper in sub/inc/, and the build
# stopped.
mkdir -p sub/src sub/inc

cat >Configfile <<'EOF2'
SUBPROJECTS += sub
EOF2

cat >sub/Configfile <<'EOF2'
LANGUAGES   += bash

BINARIES    += tool
COMPILEOPTS += -I inc
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
