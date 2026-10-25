#include "harness_start.bash"

# A "--deps" line with whitespace in front of the path -- an indented
# heredoc, a printf with a column width -- means the same path to make
# at the top of a tree, where whitespace in a prerequisite list is a
# separator.  In a subproject the line was given the project's prefix
# by pasting it onto the front of the line as written, so the prefix
# and the path came apart at the whitespace: the rule depended on
# "sub/" and on a top-level "src/answer.txt" that does not exist, and
# the build stopped with "No rule to make target".

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
--deps)     echo "  src/answer.txt" ;;
--generate) echo "#define ANSWER $(cat src/answer.txt)" ;;
esac
EOF
chmod +x sub/src/gen.h.proc

cat >sub/src/app.c <<'EOF'
  #include "gen.h"
  #include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat sub/obj/Makefile.sub

make $MAKE_ARGS
test "$(./sub/bin/app)" = "4"

sleep 2
echo 5 > sub/src/answer.txt
make $MAKE_ARGS
test "$(./sub/bin/app)" = "5"

exit 0
