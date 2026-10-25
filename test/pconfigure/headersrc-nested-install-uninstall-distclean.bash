#include "harness_start.bash"

# A HEADERSRC with a directory in its name, under a library: the copy
# lands in include/ under the same nested name, which is where a
# program in the tree finds it with an angled include, it is installed
# under the prefix's include/ at that name, and uninstall and distclean
# each take back exactly what they put down -- including the include/
# directory, which here only ever held the copy.
mkdir -p src/sub
echo 'int f(void);' > src/sub/f.h
cat >src/sub/f.c <<'EOF'
#include "f.h"
int f(void) { return 0; }
EOF
cat >src/main.c <<'EOF'
#include <sub/f.h>
int main(void) { return f(); }
EOF

cat >Configfile <<EOF
LANGUAGES += c
LANGUAGES += h

LIBRARIES += libf.so
SOURCES   += sub/f.c
HEADERSRC += sub/f.h

BINARIES  += main
DEPLIBS   += f
SOURCES   += main.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
./bin/main
cmp src/sub/f.h include/sub/f.h

make $MAKE_ARGS DESTDIR=$tempdir/dest install
cmp src/sub/f.h dest/usr/local/include/sub/f.h
test -f dest/usr/local/lib/libf.so

make $MAKE_ARGS DESTDIR=$tempdir/dest uninstall
find dest -type f > left
cat left
test ! -s left

make $MAKE_ARGS distclean
test ! -e include
test ! -e lib
test -f src/sub/f.h
test -f src/sub/f.c
