test "$(uname -s)" == "Darwin" && exit 0
#include "harness_start.bash"

# A program linked against a library built into a subdirectory of the
# lib directory.  The program records the library's soname as its
# NEEDED entry, so if that soname were "sub/libfoo.so" -- a path --
# ld.so would open it relative to wherever the program happens to be
# run from and never look along the runpath at all, and the program
# would only start from inside lib/.  Running it from the top of the
# tree, from bin/ and from / covers the places anybody actually runs
# it from.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += c

LIBRARIES += sub/libfoo.so
SOURCES   += foo.c

BINARIES  += app
LINKOPTS  += -Llib/sub
DEPLIBS   += foo
SOURCES   += main.c
EOF

echo 'int foo(void) { return 7; }' >src/foo.c

cat >src/main.c <<'EOF'
#include <stdio.h>
int foo(void);
int main(void) { printf("%d\n", foo()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

readelf -d bin/app > app.dynamic
cat app.dynamic
if grep -q '(NEEDED).*\[.*/.*\]' app.dynamic
then
    echo "a NEEDED entry contains a '/' -- it's a path, not a name" >&2
    exit 1
fi

test "$(./bin/app)" = "7"
test "$(cd bin && ./app)" = "7"
test "$(cd / && $tempdir/bin/app)" = "7"
