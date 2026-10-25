#include "harness_start.bash"

# A prebuilt object named outright on a LINKOPTS line has to relink the
# program when it changes, like any other input to the link.
#
# AUTORECONFIGURE = true, where what gets linked is every ".o" make
# found among the link's prerequisites.  The object is already on the
# link line once, as the LINKOPTS word it was written as, so its being
# a prerequisite too must not put it there a second time: a second
# copy of v() is a link that fails on a duplicate symbol.

mkdir -p src vendor

cat >Configfile <<'EOF'
AUTORECONFIGURE = true

LANGUAGES += c

BINARIES  += app
LINKOPTS  += vendor/v.o
SOURCES   += main.c
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
int v(void);
int main(void) { printf("%d\n", v()); return 0; }
EOF

build_vendor() {
    echo "int v(void) { return $1; }" >vendor/v.c
    cc -c vendor/v.c -o vendor/v.o
}

build_vendor 1
$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "1"

# Far enough in the past that the new object is newer whatever the
# filesystem's timestamp resolution.
find . -type f -exec touch -d '2000-01-01' {} +

build_vendor 2
make $MAKE_ARGS
test "$(./bin/app)" = "2"
