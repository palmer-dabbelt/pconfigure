#include "harness_start.bash"

# compileopts-undefine-turns-ifdef-off.bash under AUTORECONFIGURE,
# where pdeps reads the options during the build.  "-DEXTRA -UEXTRA"
# leaves EXTRA undefined to the compiler, so nothing reads extra.h and
# the source behind it -- which doesn't compile -- has no business in
# the link.

mkdir -p src

cat >Configfile <<'EOF'
AUTORECONFIGURE = true

LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -DEXTRA -UEXTRA
SOURCES     += main.c
EOF

echo 'int extra(void);' >src/extra.h
echo '#error "EXTRA was undefined, so nothing reads extra.h"' >src/extra.c

cat >src/main.c <<'EOF'
#ifdef EXTRA
#include "extra.h"
#endif
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
./bin/app
