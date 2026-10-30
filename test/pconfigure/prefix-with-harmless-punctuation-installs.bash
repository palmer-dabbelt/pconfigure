#include "harness_start.bash"

# A PREFIX is refused for the characters make or the shell reads in a
# name, but not for the punctuation neither does: '~' in the middle of
# a path, '^', '!', '@', '+' and '-' are all ordinary characters in a
# recipe run by a non-interactive shell.  Such a prefix compiles into
# the program as __PCONFIGURE__PREFIX, becomes the installed copy's
# RUNPATH exactly as written, and installs and uninstalls under itself.
mkdir -p src
cat > src/main.c <<'EOF2'
#include <stdio.h>
int main(void) { puts(__PCONFIGURE__PREFIX); return 0; }
EOF2
echo 'int f(void) { return 0; }' > src/f.c

cat >Configfile <<'EOF2'
PREFIX     = /opt/a~b^c!d@e+f-g
LANGUAGES += c

LIBRARIES += libf.so
SOURCES   += f.c

BINARIES  += main
DEPLIBS   += f
SOURCES   += main.c
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(bin/main)" == '/opt/a~b^c!d@e+f-g'

make $MAKE_ARGS DESTDIR=$tempdir/dest install
test -x 'dest/opt/a~b^c!d@e+f-g/bin/main'
test -f 'dest/opt/a~b^c!d@e+f-g/lib/libf.so'
if test "$(uname -s)" == "Darwin"; then otool -l 'dest/opt/a~b^c!d@e+f-g/bin/main' | grep -F '/opt/a~b^c!d@e+f-g/lib'; else readelf -d 'dest/opt/a~b^c!d@e+f-g/bin/main' | grep -F '[/opt/a~b^c!d@e+f-g/lib]'; fi

make $MAKE_ARGS DESTDIR=$tempdir/dest uninstall
test -z "$(find dest -type f)"
