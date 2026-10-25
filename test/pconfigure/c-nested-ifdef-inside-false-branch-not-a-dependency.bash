#include "harness_start.bash"

# The header scan for C reads conditionals the same way the script
# reader does, so it had the same blind spot: an "#ifndef" nested in an
# "#ifdef" that is off was judged on its own and its "#include" was
# followed.  The compiler never reads that header, but the scan both
# lists it as a dependency and goes looking for the source behind it --
# and that source, which nothing asked for, gets built and linked in.
# Here it doesn't even compile, so the build says so directly.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += c

BINARIES  += app
SOURCES   += main.c
EOF

cat >src/extras.h <<'EOF'
int extras(void);
EOF

cat >src/extras.c <<'EOF'
#error "extras.c is only meant to be built WITH_EXTRAS"
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
#ifdef WITH_EXTRAS
#ifndef EXTRAS_ARE_BUILTIN
#include "extras.h"
#endif
#endif
int main(void) { printf("app\n"); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

if grep -q "src/extras\.[ch]" Makefile
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/app)" = "app"
