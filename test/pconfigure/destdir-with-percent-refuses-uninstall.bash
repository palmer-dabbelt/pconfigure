#include "harness_start.bash"

# "make uninstall" is a phony goal whose prerequisites are one phony
# rule per installed file, each named "__pconfigure__uninstall-" and
# then the file's "$(DESTDIR)/..." path.  A '%' in a target name makes
# it a pattern, though, so with a DESTDIR like "stage-100%" every one
# of those rules became a pattern rule, make never looks for a pattern
# rule for a phony target, and "make uninstall" said "Nothing to be
# done" and exited 0 with everything still installed.  The install
# went through only because "install: <path>" happens to match the
# pattern rule it turned into, so the two goals that are meant to undo
# each other quietly didn't.  Both are refused with the explanation
# whitespace in a DESTDIR gets.
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

# Installed the honest way, through a name without the '%', so that
# there is something for the uninstall to leave behind.
mkdir "$tempdir/stage-100%"
ln -s "$tempdir/stage-100%" "$tempdir/stage-link"
make $MAKE_ARGS DESTDIR="$tempdir/stage-link" install
test -x "$tempdir/stage-100%/usr/local/bin/main"

if make $MAKE_ARGS DESTDIR="$tempdir/stage-100%" uninstall > uninstall.out 2>&1
then
    cat uninstall.out
    exit 1
fi
cat uninstall.out
grep -F "DESTDIR=\"$tempdir/stage-100%\"" uninstall.out
test -x "$tempdir/stage-100%/usr/local/bin/main"

if make $MAKE_ARGS DESTDIR="$tempdir/stage-100%" install > install.out 2>&1
then
    cat install.out
    exit 1
fi
cat install.out
grep -F "DESTDIR=\"$tempdir/stage-100%\"" install.out

# And the name the install went through takes it all back out.
make $MAKE_ARGS DESTDIR="$tempdir/stage-link" uninstall
find "$tempdir/stage-100%" -type f > left
cat left
test ! -s left
