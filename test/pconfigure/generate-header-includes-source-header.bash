#include "harness_start.bash"

# A generated header that includes an ordinary header from the source
# tree: the consumer depends on the generated header, and through it
# on the hand-written one, so editing the hand-written header has to
# recompile the consumer even though no source names it directly.
#
# The generated header reaches it by a path relative to itself, which
# is how a quoted include is resolved first: the source directory is
# not on the include path, and the header is not next to the source.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h

BINARIES  += app
SOURCES   += app.c
EOF

cat >src/base.h <<'EOF'
#define BASE 10
EOF

cat >src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--generate) echo '#include "../../src/base.h"'
            echo "#define ANSWER (BASE + 1)" ;;
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
test "$(./bin/app)" = "11"

sleep 2
echo "#define BASE 20" > src/base.h
make $MAKE_ARGS
test "$(./bin/app)" = "21"

exit 0
