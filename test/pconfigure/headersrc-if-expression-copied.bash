#include "harness_start.bash"

# A header copy is the header, byte for byte, and nothing in it is read
# the way pbashc reads a script: an "#if" in it is the compiler's, for
# whatever includes the copy.  The copy was scanned as a script for its
# includes, and that scan refuses an "#if" outright.
mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES += c
LANGUAGES += h

HEADERSRC += x.h

BINARIES += main
SOURCES += main.c
EOF2

cat >src/x.h <<'EOF2'
#if defined(__GNUC__) || 1
#define X 1
#else
#define X 0
#endif
EOF2

cat >src/main.c <<'EOF2'
#include <x.h>
int main(void) { return X == 1 ? 0 : 1; }
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
cmp src/x.h include/x.h
./bin/main

exit 0
