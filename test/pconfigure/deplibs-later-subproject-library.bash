#include "harness_start.bash"

# A binary that links a library from a subproject named below it.
# Every other test that links across projects lists SUBPROJECTS
# first, so the library's project has been read by the time the
# binary's "-l" is.  Here it hasn't, and the "-l" can only be matched
# against the subproject's library once every project is known.

mkdir -p src late/src

cat >Configfile <<EOF
LANGUAGES   += c

BINARIES    += app
LINKOPTS    += -L late/lib
DEPLIBS     += late
SOURCES     += main.c

SUBPROJECTS += late
EOF

cat >late/Configfile <<EOF
LANGUAGES += c

LIBRARIES += liblate.so
SOURCES   += late.c
EOF

cat >late/src/late.c <<'EOF'
int late(void) { return 11; }
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
int late(void);
int main(void) { printf("%d\n", late()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

grep -q "^obj/bin/app/.*/local: late/lib/liblate.so$" Makefile

# Asking for the top project's binary alone, in parallel, has to reach
# into the subproject and build its library first.
make $MAKE_ARGS -j2 bin/app
test -f late/lib/liblate.so
test "$(./bin/app)" = "11"
