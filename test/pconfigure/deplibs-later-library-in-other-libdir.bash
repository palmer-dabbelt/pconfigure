#include "harness_start.bash"

# A library declared below the binary that links it, and built into a
# LIBDIR of its own.  Two things have to hold at once for the binary
# to get it as a prerequisite: the "-l" has to be matched against a
# target that hadn't been read yet when the binary was, and the match
# has to go through the "-L" the binary names rather than through its
# own LIBDIR, which is still the default "lib" and builds nothing.
# The tests that already put a DEPLIBS above its library only ever
# find that library in "lib".

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

BINARIES  += app
LINKOPTS  += -L altlib
DEPLIBS   += late
SOURCES   += main.c

LIBDIR     = altlib
LIBRARIES += liblate.so
SOURCES   += late.c
EOF

cat >src/late.c <<'EOF'
int late(void) { return 11; }
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
int late(void);
int main(void) { printf("%d\n", late()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# The dependency is written against the library where it comes out,
# not where the binary's own LIBDIR would have put it.
grep -q "^obj/bin/app/.*/local: altlib/liblate.so$" Makefile

# ... and it's one make acts on: asking for the binary alone, in
# parallel, builds the library first, and the binary that comes out
# finds it when it runs.
make $MAKE_ARGS -j2 bin/app
test -f altlib/liblate.so
test "$(./bin/app)" = "11"
