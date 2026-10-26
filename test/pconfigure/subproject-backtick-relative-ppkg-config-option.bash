#include "harness_start.bash"

# "--ppkg-config PATH" is a path like every other one on the command
# line, relative to the directory pconfigure was started in.  A
# subproject's backticks run in the subproject's own directory, so the
# path has to reach them as the program it named there rather than as
# the same words read from somewhere else.
mkdir -p tools lib/src

cat >tools/my-ppkg <<'EOF'
#!/bin/bash
echo "-DFROM_MY_PPKG=7"
EOF
chmod +x tools/my-ppkg

cat >lib/Configfile <<'EOF'
LANGUAGES   += c
BINARIES    += test
COMPILEOPTS += `ppkg-config thing --cflags`
SOURCES     += test.c
EOF

cat >lib/src/test.c <<'EOF'
#include <stdio.h>
int main(void) { printf("%d\n", FROM_MY_PPKG); return 0; }
EOF

echo 'SUBPROJECTS += lib' >Configfile

$PTEST_BINARY $PCONFIGURE_ARGS --ppkg-config tools/my-ppkg

make $MAKE_ARGS
test "$(./lib/bin/test)" = "7"

exit 0
