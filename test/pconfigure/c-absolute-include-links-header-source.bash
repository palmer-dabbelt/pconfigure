#include "harness_start.bash"

# An "#include" may name its header by an absolute path, which is what
# a tool that writes C for a build tends to do, and the compiler opens
# exactly that file.  The scan stuck the includer's directory on the
# front of it anyway -- "src/" and "/tmp/..." made "src//tmp/..." --
# found nothing there or along the include path, and left the header
# out.  The source behind it was then never built, and the link failed
# on extra().

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += app
SOURCES     += main.c
EOF

cat >src/extra.h <<'EOF'
int extra(void);
EOF

cat >src/extra.c <<'EOF'
int extra(void) { return 7; }
EOF

cat >src/main.c <<EOF
#include <stdio.h>
#include "$tempdir/src/extra.h"
int main(void) { printf("%d\n", extra()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "7"
