#include "harness_start.bash"

# A "--deps" line naming two inputs separated by a space works at the
# top of a tree, since make reads both as prerequisites.  In a
# subproject the prefix went onto the front of the line rather than
# onto each path, so the second path was left naming a file at the top
# of the parent tree, which does not exist, and the build stopped.

mkdir -p sub/src

cat >Configfile <<EOF
SUBPROJECTS += sub
EOF

cat >sub/Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h

BINARIES  += app
SOURCES   += app.c
EOF

echo 4 > sub/src/answer.txt

cat >sub/src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     echo "src/answer.txt src/other.txt" ;;
--generate) echo "#define ANSWER $(cat src/answer.txt)" ;;
esac
EOF
chmod +x sub/src/gen.h.proc

cat >sub/src/app.c <<'EOF'
  #include "gen.h"
  #include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

echo 0 > sub/src/other.txt

$PTEST_BINARY $PCONFIGURE_ARGS
cat sub/obj/Makefile.sub

make $MAKE_ARGS
test "$(./sub/bin/app)" = "4"

# And the second path is watched, not merely tolerated: rewriting it
# regenerates the output like rewriting the first would.
sleep 2
echo 1 > sub/src/other.txt
make $MAKE_ARGS > again.out 2>&1
cat again.out
grep -q "^GEN	gen.h$" again.out

exit 0
