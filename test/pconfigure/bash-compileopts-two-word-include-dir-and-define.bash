#include "harness_start.bash"

# COMPILEOPTS is written for compilers, and a compiler takes "-I inc"
# and "-D FANCY" as readily as "-Iinc" and "-DFANCY".  pbashc only
# read the stuck-on spelling: the "-I" alone added an empty directory
# and "inc" was then taken for the script to compile, so what came out
# was a shebang with nothing under it, and the build said it worked.
mkdir -p src inc

cat >Configfile <<EOF
LANGUAGES   += bash

BINARIES    += tool
COMPILEOPTS += -I inc
COMPILEOPTS += -D FANCY
SOURCES     += tool.bash
EOF

cat >src/tool.bash <<'EOF'
#include "helper.bash"
#ifdef FANCY
echo fancy
#endif
echo tool
EOF

cat >inc/helper.bash <<'EOF'
echo helper
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
cat bin/tool
test "$(./bin/tool)" = "helper
fancy
tool"

exit 0
