#include "harness_start.bash"

# pbashc writes its own "#!" line at the top of what it compiles, and
# used to leave the script's own first line underneath it as a comment.
# Whatever that line asked of the shell went with it: a script that
# starts "#!/bin/bash -e" was compiled into one that carries on past a
# failing command, which is the one thing it was written never to do.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/tool.bash <<'EOF'
#!/bin/bash -e
false
echo should-not-get-here
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
cat bin/tool

# The interpreter is still the one pbashc chose, with the script's
# option carried onto it, and the script's own "#!" line is gone
# rather than left behind as a second one.
head -n 1 bin/tool | grep -qx '#!.*/bin/bash -e'
test "$(grep -c '^#!' bin/tool)" = 1

if ./bin/tool > tool.out
then
    cat tool.out
    exit 1
fi
cat tool.out
if grep -q should-not-get-here tool.out
then
    exit 1
fi
