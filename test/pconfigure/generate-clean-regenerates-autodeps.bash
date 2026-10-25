#include "harness_start.bash"

# With AUTODEPS the dependencies of a source are worked out by the
# build, from a fragment pdeps writes, rather than by pconfigure.  A
# "make clean" takes the generated header away; the build after it
# has to generate it again before compiling the consumer, rather than
# deriving a fragment that no longer mentions it and compiling first.
# And the consumer still hears about the next change to the script's
# input afterwards.

mkdir -p src

cat >Configfile <<EOF
AUTODEPS   = true
LANGUAGES += c

GENERATE  += gen.h

BINARIES  += app
SOURCES   += app.c
EOF

echo 4 > src/answer.txt

cat >src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     echo "src/answer.txt" ;;
--generate) echo "#define ANSWER $(cat src/answer.txt)" ;;
esac
EOF
chmod +x src/gen.h.proc

cat >src/app.c <<'EOF'
  #include "gen.h"
  #include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "4"

make $MAKE_ARGS clean
test ! -e obj/proc/gen.h
make $MAKE_ARGS -j2
test "$(./bin/app)" = "4"

sleep 2
echo 9 > src/answer.txt
make $MAKE_ARGS
test "$(./bin/app)" = "9"

exit 0
