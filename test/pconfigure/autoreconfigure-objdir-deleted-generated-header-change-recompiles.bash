#include "harness_start.bash"

# Deleting the object directory is documented as costing a rebuild of
# what was in there and nothing more.  Under AUTORECONFIGURE that
# includes the GENERATE output, which lives in obj/proc, and the
# fragments pdeps derives -- and the fragment for the source that
# reads the generated header has to come out naming it, or the next
# change to the generator's input regenerates the header and leaves
# the program compiled against the old one.
export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src

cat >Configfile <<EOF
AUTORECONFIGURE = true

LANGUAGES += c

GENERATE  += gen.h

BINARIES  += app
SOURCES   += app.c
EOF

echo 1 > src/answer.txt

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
test "$(./bin/app)" = "1"

rm -rf obj
make $MAKE_ARGS
test "$(./bin/app)" = "1"

sleep 2
echo 2 > src/answer.txt
make $MAKE_ARGS
test "$(./bin/app)" = "2"

exit 0
