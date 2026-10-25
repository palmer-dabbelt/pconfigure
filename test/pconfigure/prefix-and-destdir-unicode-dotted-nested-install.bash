#include "harness_start.bash"

# A PREFIX and a DESTDIR with UTF-8, dots and dashes in them, holding a
# nested program and the library it links: none of those characters
# mean anything to make or the shell, so they should reach the
# compiled-in __PCONFIGURE__PREFIX, the installed RUNPATH and every
# install and uninstall recipe exactly as written.
mkdir -p src
echo 'int f(void) { return 0; }' > src/f.c
cat >src/main.c <<'EOF'
#include <stdio.h>
int f(void);
int main(void) { puts(__PCONFIGURE__PREFIX); return f(); }
EOF

cat >Configfile <<EOF
LANGUAGES += c
PREFIX     = /opt/ünï-1.0

LIBRARIES += libf.so
SOURCES   += f.c

BINARIES  += tools/main
DEPLIBS   += f
SOURCES   += main.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/tools/main)" = "/opt/ünï-1.0"

dest="$tempdir/dëst.d-1"
make $MAKE_ARGS DESTDIR="$dest" install
test -x "$dest/opt/ünï-1.0/bin/tools/main"
test -f "$dest/opt/ünï-1.0/lib/libf.so"
readelf -d "$dest/opt/ünï-1.0/bin/tools/main" > installed.dyn
cat installed.dyn
grep -q 'R.*PATH.*\[/opt/ünï-1.0/lib\]' installed.dyn

make $MAKE_ARGS DESTDIR="$dest" uninstall
find "$dest" -type f > left
cat left
test ! -s left
