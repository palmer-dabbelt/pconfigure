#include "harness_start.bash"

# A GENERATE written below the BINARIES whose source includes its
# output.  The source used to be scanned before the header had been
# generated, so its object was never made to depend on the header: the
# first build worked, because by then the header existed, but an edited
# input regenerated the header while the binary went on printing the
# old answer.  The generator-binary shape (a tool built from the
# project's own sources, then a GENERATE that runs it) needs a GENERATE
# below a target to be legal, so the answer is to get the dependency
# right wherever the line sits rather than to refuse it.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

BINARIES  += app
SOURCES   += app.c

GENERATE  += gen.h
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
cat Makefile

make $MAKE_ARGS
test "$(./bin/app)" = "4"

# Far enough apart that make can't mistake the edit for something
# older than the header it already built.
sleep 2
echo 8 > src/answer.txt
make $MAKE_ARGS
test "$(./bin/app)" = "8"
