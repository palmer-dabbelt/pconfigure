#include "harness_start.bash"

# A "--deps" line holding an absolute path names a file outside the
# tree -- a system header, a toolchain somewhere else -- and at the top
# of a tree it reaches the rule as written, so an edit to that file
# regenerates the output and the consumer is rebuilt.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h

BINARIES  += app
SOURCES   += app.c
EOF

cat >src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     echo "@OUTSIDE@" ;;
--generate) echo "#define ANSWER $(cat @OUTSIDE@)" ;;
esac
EOF
chmod +x src/gen.h.proc

# Filled in here because the directory this runs in is only known now.
mkdir -p elsewhere
echo 4 > elsewhere/answer.txt
sed -i "s|@OUTSIDE@|$(pwd)/elsewhere/answer.txt|g" src/gen.h.proc

cat >src/app.c <<'EOF'
  #include "gen.h"
  #include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
grep -q "^obj/proc/gen.h: .*$(pwd)/elsewhere/answer.txt" Makefile

make $MAKE_ARGS
test "$(./bin/app)" = "4"

sleep 2
echo 5 > elsewhere/answer.txt
make $MAKE_ARGS
test "$(./bin/app)" = "5"

exit 0
