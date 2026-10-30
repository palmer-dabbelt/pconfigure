#include "harness_start.bash"

# A prebuilt archive the project doesn't build -- a vendored blob,
# say -- named outright on a LINKOPTS line.  Its members are copied
# into the program, so a new copy of the archive has to relink it.
# Nothing in the build makes the file, so the link rule never named it
# as a prerequisite, and "make" after the archive was replaced kept the
# program built from the old one.

mkdir -p src vendor

cat >Configfile <<'EOF'
LANGUAGES += c

BINARIES  += app
LINKOPTS  += vendor/libv.a
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
    rm -f vendor/libv.a
    ar rcs vendor/libv.a vendor/v.o
}

build_vendor 1
$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "1"

# Far enough in the past that the new archive is newer whatever the
# filesystem's timestamp resolution.
find . -type f -exec touch -t 200001010000 {} +

build_vendor 2
make $MAKE_ARGS
test "$(./bin/app)" = "2"
