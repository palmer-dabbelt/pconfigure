#include "harness_start.bash"

# Under AUTORECONFIGURE the headers a source reads are worked out by
# pdeps during the build, and a header the build itself produces --
# a GENERATE output -- is one of them.  A fresh configure generates
# it before anything is scanned, so the first build finds it.  "make
# clean" takes it away again, and the build after the clean has to
# generate it before it asks pdeps what the consumer reads: a fragment
# derived while the header is missing simply leaves it out, and from
# then on a change to the generator's input regenerates the header
# without recompiling the program that reads it.
export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src

cat >Configfile <<EOF
AUTORECONFIGURE = true

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

# A serial build after the clean: make reaches the consumer's
# fragment before it reaches anything that would generate the header.
make $MAKE_ARGS clean
test ! -e obj/proc/gen.h
make $MAKE_ARGS
test "$(./bin/app)" = "4"

# Whatever order that happened in, the header is now a prerequisite of
# the object again.
cat obj/src/app.c/*.d
grep -q "^obj/src/app.c/.*\.o:.* obj/proc/gen.h" obj/src/app.c/*.d

# And the thing that prerequisite is for: the input changes, the
# header is regenerated, and the program follows it.
sleep 2
echo 9 > src/answer.txt
make $MAKE_ARGS
test "$(./bin/app)" = "9"

exit 0
