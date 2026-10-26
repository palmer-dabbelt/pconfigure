#include "harness_start.bash"

# A generated header is scanned like any other, so a header it includes
# brings the source behind that header into the link -- on the very
# first configure, since every GENERATE is run before the scan.  A
# generated wrapper around a hand-written API is the usual shape.
# Whether editing that hand-written header recompiles is a separate
# question, and generate-header-includes-source-header.bash asks it;
# this one only asks whether helper.c is linked at all, which it has to
# be or the program doesn't link.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c
BINARIES  += app
SOURCES   += app.c
GENERATE  += gen.h
EOF

cat >src/gen.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--generate) echo '#include "../../src/helper.h"'
            echo "#define ANSWER helper()" ;;
esac
EOF
chmod +x src/gen.h.proc

cat >src/helper.h <<'EOF'
int helper(void);
EOF

cat >src/helper.c <<'EOF'
int helper(void) { return 7; }
EOF

cat >src/app.c <<'EOF'
#include "gen.h"
#include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS -j2
test "$(./bin/app)" = "7"

exit 0
