#include "harness_start.bash"

# "-DNAME=value" replaces NAME everywhere in the output, and the output
# includes what was pasted in: a helper's use of the name is replaced
# just as the script's own is.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash
COMPILEOPTS += -DGREETING=hello

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/tool.bash <<'EOF'
#include "helper.bash"
echo "tool GREETING"
EOF

cat >src/helper.bash <<'EOF'
echo "helper GREETING"
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/tool)" = "helper hello
tool hello"
