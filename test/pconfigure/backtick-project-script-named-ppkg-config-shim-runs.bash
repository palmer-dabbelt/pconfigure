#include "harness_start.bash"

# "ppkg-config" is replaced as a word, and tools/ppkg-config-shim -- a
# project's own script, in a directory of its own -- is a different
# word that happens to have it inside.  Spliced into, it becomes
# "tools/" followed by an absolute path, which names nothing, and the
# configure stops on a command the Configfile never wrote.

export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src tools

cat >tools/ppkg-config-shim <<'EOC'
#!/bin/sh
echo -DFROM_SHIM=1
EOC
chmod +x tools/ppkg-config-shim

cat >Configfile <<'EOC'
LANGUAGES   += c
COMPILEOPTS += `tools/ppkg-config-shim`
BINARIES    += app
SOURCES     += main.c
EOC

cat >src/main.c <<'EOC'
#include <stdio.h>
int main(void) { printf("%d\n", FROM_SHIM); return 0; }
EOC

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "1"
