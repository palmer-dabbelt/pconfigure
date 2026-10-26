#include "harness_start.bash"

# Every install recipe pastes $(DESTDIR) bare into a shell command,
# and the shell takes a backslash as escaping the character after it.
# "make DESTDIR='st\age' install" therefore copied everything into
# "stage", a directory nobody named, and reported success.  A DESTDIR
# with whitespace, ':', ';' or '%' is refused with a sentence about
# DESTDIR; this one either has to be refused the same way or install
# where it says.  Either way nothing may appear under "stage".
mkdir -p src include
echo 'int main(void) { return 0; }' > src/main.c
echo 'echo hi' > src/script.bash
echo 'int f(void);' > include/main.h

cat >Configfile <<'EOF2'
LANGUAGES += c
LANGUAGES += bash

BINARIES  += main
SOURCES   += main.c

BINARIES  += script
SOURCES   += script.bash

HEADERS   += main.h
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

destdir="$tempdir/st\\age"
if make $MAKE_ARGS DESTDIR="$destdir" install > install.out 2>&1
then
    cat install.out
    test -x "$destdir/usr/local/bin/main"
    test -x "$destdir/usr/local/bin/script"
    test -f "$destdir/usr/local/include/main.h"
else
    cat install.out
    grep -F "DESTDIR=\"$destdir\"" install.out
fi

ls -a
test ! -e "$tempdir/stage"
