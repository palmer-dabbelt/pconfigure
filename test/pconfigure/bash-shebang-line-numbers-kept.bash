#include "harness_start.bash"

# A script that starts with its own "#!" line has that line replaced
# by pbashc's rather than pushed down under it, so every line of the
# compiled program is on the line it was on in the source.  It used to
# be two further down -- pbashc's "#!", a blank line, then the script
# -- so an error message, a "set -x" trace or $LINENO named a line the
# source doesn't have that text on.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/tool.bash <<'EOF'
#!/bin/bash
echo "line $LINENO"
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
cat bin/tool

./bin/tool > tool.out
cat tool.out
grep -qx "line 2" tool.out
