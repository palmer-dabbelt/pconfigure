#include "harness_start.bash"

# pbashc carries the options on a script's "#!" line over to its own,
# but in "#!/usr/bin/env bash" the word after the interpreter is the
# program env is to find, not an option for it.  Carried over, it
# would make the compiled program "/bin/bash bash": a shell told to run
# a script called "bash" instead of the one it was handed.  Only what
# comes after the program's name is an option, so here there is
# nothing to carry.  The line it replaces is still dropped, which is
# what keeps $LINENO matching the source.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/tool.bash <<'EOF'
#!/usr/bin/env bash
echo "line $LINENO"
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
cat bin/tool

head -n 1 bin/tool | grep -qx '#!.*/bin/bash'

./bin/tool > tool.out
cat tool.out
grep -qx "line 2" tool.out
