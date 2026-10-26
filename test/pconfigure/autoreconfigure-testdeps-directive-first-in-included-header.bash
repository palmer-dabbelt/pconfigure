#include "harness_start.bash"

# The C counterpart of
# autoreconfigure-testdeps-directive-first-in-included-script.bash: a C
# test's "#pconfigure TESTDEPS" can come from a header it includes, so
# that header has to be watched before it holds one, or adding the first
# reconfigures nothing.  The test also includes a system header, which
# is no part of the project and must not land on the watched list -- a
# Makefile that reconfigured whenever the system's libc was upgraded
# would be reconfiguring for nothing it reads.

export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src test/uses-tool

cat >Configfile <<'EOC'
AUTORECONFIGURE  = true
LANGUAGES       += c
TESTEXECS       += tool
SOURCES         += tool.c
BINARIES        += uses-tool
SOURCES         += uses-tool.c
TESTSRC         += finds-tool.c
EOC

echo 'int main(void) { return 0; }' > src/tool.c
echo 'int main(void) { return 0; }' > src/uses-tool.c

cat > test/uses-tool/finds-tool.c <<'EOF_C'
#include <stdio.h>
#include "helper.h"
int main(void) { return 0; }
EOF_C
echo '/* nothing yet */' > test/uses-tool/helper.h

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
if grep -q '^check/uses-tool/finds-tool.c:.*testexec/tool' Makefile
then
    exit 1
fi

# Whatever the watched list is written into, it names files by the
# paths they were found at, and nothing outside the project.
if grep -q 'stdio\.h' Makefile
then
    grep 'stdio\.h' Makefile
    exit 1
fi

sleep 1
echo '#pconfigure TESTDEPS += testexec/tool' > test/uses-tool/helper.h

make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
grep -q "^PCONFIGURE$" second.log
grep -q '^check/uses-tool/finds-tool.c:.*testexec/tool' Makefile
