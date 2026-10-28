#include "harness_start.bash"

# The installed half of nested-library-consumer-runs-from-anywhere: a
# program linked against "sub/libfoo.so" asks the loader for plain
# "libfoo.so", which installs as lib/sub/libfoo.so under the prefix.
# The installed program is linked without the build tree's runpath, so
# unless its own runpath reaches the prefix's lib/sub it finds the
# library from no directory at all.  It's run from / with the build
# tree's libraries moved out of the way, so the installed copy is the
# only one there is to find.
mkdir -p src

cat >Configfile <<EOF2
PREFIX     = $tempdir/inst
LANGUAGES += c

LIBRARIES += sub/libfoo.so
SOURCES   += foo.c

BINARIES  += app
LINKOPTS  += -Llib/sub
LINKOPTS  += -L./lib/sub
DEPLIBS   += foo
SOURCES   += main.c
EOF2

echo 'int foo(void) { return 7; }' >src/foo.c

cat >src/main.c <<'EOF2'
#include <stdio.h>
int foo(void);
int main(void) { printf("%d\n", foo()); return 0; }
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS install

test -f inst/lib/sub/libfoo.so

# The two "-L"s above are two spellings of one directory, and it's in
# the runpath once.
if test "$(uname -s)" != "Darwin"
then
    readelf -d inst/bin/app > app.dynamic
    cat app.dynamic
    test "$(grep -o "$tempdir/inst/lib/sub" app.dynamic | wc -l | tr -d ' ')" = 1
fi

mv lib lib.moved
test "$(cd / && $tempdir/inst/bin/app)" = "7"
