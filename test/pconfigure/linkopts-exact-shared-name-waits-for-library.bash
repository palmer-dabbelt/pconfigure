#include "harness_start.bash"

# The shared-library spelling of "-l:NAME": "-l:libbar.so" names the
# file outright.  As with "-l:libfoo.a", the link depends on the
# library it asks for, so building the program alone -- or a parallel
# build that reaches it first -- makes lib/libbar.so before linking.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += c

BINARIES  += app
LINKOPTS  += -l:libbar.so
SOURCES   += main.c

LIBRARIES += libbar.so
SOURCES   += bar.c
EOF

echo 'int bar(void) { return 10; }' >src/bar.c

cat >src/main.c <<'EOF'
#include <stdio.h>
int bar(void);
int main(void) { printf("%d\n", bar()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

make $MAKE_ARGS bin/app
test "$(./bin/app)" = "10"
