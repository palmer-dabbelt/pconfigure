#include "harness_start.bash"

# DESTDIR is the packager's, not the project's: it is said on the make
# command line, long after pconfigure ran, and a staging directory
# with a space in its name is an ordinary one.  The install rules name
# their outputs "$(DESTDIR)/usr/local/bin/main" though, and a target
# name is a word of make rather than of shell -- so make split "stage
# dir/usr/local/bin/main" into a target "stage" and a target
# "dir/usr/local/bin/main", and the program was installed into a
# "dir/" in the middle of the source tree while the staging directory
# got nothing.  Make has no way to spell such a target, so the install
# is refused with a message saying why instead.
mkdir -p src include
echo 'int main(void) { return 0; }' > src/main.c
printf '#!/bin/bash\necho hi\n' > src/script.bash
echo 'int f(void);' > include/main.h

cat >Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash

BINARIES  += main
SOURCES   += main.c

BINARIES  += script
SOURCES   += script.bash

HEADERS   += main.h
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

if make $MAKE_ARGS DESTDIR="$tempdir/stage dir" install > install.out 2>&1
then
    cat install.out
    exit 1
fi
cat install.out
grep -F 'DESTDIR' install.out
grep -F "$tempdir/stage dir" install.out

# Nothing landed anywhere on the way: not in the source tree, and not
# in either half of the name.
test ! -e dir
test ! -e "$tempdir/stage"
test ! -e "$tempdir/stage dir"

# What the message suggests instead -- a spelling of the same
# directory without the space -- installs into the directory that
# has one.
mkdir "$tempdir/stage dir"
ln -s "$tempdir/stage dir" "$tempdir/stage-link"
make $MAKE_ARGS DESTDIR="$tempdir/stage-link" install
test -x "$tempdir/stage dir/usr/local/bin/main"
test -x "$tempdir/stage dir/usr/local/bin/script"
test -f "$tempdir/stage dir/usr/local/include/main.h"
test ! -e dir
