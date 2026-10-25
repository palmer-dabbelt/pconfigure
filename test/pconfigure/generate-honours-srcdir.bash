#include "harness_start.bash"

# A GENERATE's script is looked for under SRCDIR, as a SOURCES is,
# and what its "--deps" prints is relative to the top of the project
# rather than to SRCDIR -- the script is run from the top.  A tree that
# keeps its code in "source/" rather than "src/" uses both.

mkdir -p source data

cat >Configfile <<EOF
LANGUAGES += c
SRCDIR     = source

GENERATE  += gen.h

BINARIES  += app
SOURCES   += app.c
EOF

echo 4 > data/answer.txt

cat >source/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     echo "data/answer.txt" ;;
--generate) echo "#define ANSWER $(cat data/answer.txt)" ;;
esac
EOF
chmod +x source/gen.h.proc

cat >source/app.c <<'EOF'
  #include "gen.h"
  #include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
grep -q "^obj/proc/gen.h: source/gen.h.proc data/answer.txt" Makefile

make $MAKE_ARGS
test "$(./bin/app)" = "4"

sleep 2
echo 6 > data/answer.txt
make $MAKE_ARGS
test "$(./bin/app)" = "6"

exit 0
