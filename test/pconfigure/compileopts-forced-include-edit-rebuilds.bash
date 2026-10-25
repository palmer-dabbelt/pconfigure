#include "harness_start.bash"

# "-include FILE" makes the compiler read FILE ahead of the source, as
# though the source's first line included it.  It is as much a header
# of every object built under it as any "#include" is, but the scan
# used to read only the include path and the defines out of the
# options, so the file was no prerequisite of anything: editing it
# rebuilt nothing, and the program went on carrying the old value.
#
# AUTORECONFIGURE = false, which is what decides who reads the options:
# pconfigure does under false and pdeps does under true, and the two
# have to agree with each other as well as with the compiler.

mkdir -p src

cat >Configfile <<'EOF'
AUTORECONFIGURE = false

LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -include src/config.h
SOURCES     += main.c
EOF

cat >src/config.h <<'EOF'
#define VALUE 1
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
int main(void) { printf("%d\n", VALUE); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "1"

# Far enough in the past that the edit below is newer whatever the
# filesystem's timestamp resolution.
find . -type f -exec touch -d '2000-01-01' {} +

cat >src/config.h <<'EOF'
#define VALUE 2
EOF

make $MAKE_ARGS
test "$(./bin/app)" = "2"
