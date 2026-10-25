#include "harness_start.bash"

# A blank line in a "--deps" answer -- a stray "echo" between two
# names -- declares nothing.  At the top of a tree that is what it
# does.  In a subproject the project's prefix was pasted onto the empty
# line, so the rule depended on the subproject's own directory, and
# every file created directly in it regenerated the output.  That is
# the very thing a bare '?' is refused for; a blank line got it with no
# word said.

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
--deps)     echo "src/answer.txt"; echo ;;
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

# Nothing the script reads changed, so nothing is generated.
sleep 2
touch sub/unrelated-file
make $MAKE_ARGS > again.out 2>&1
cat again.out
if grep -q "^GEN" again.out
then
    exit 1
fi

exit 0
