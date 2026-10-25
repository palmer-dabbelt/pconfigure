#include "harness_start.bash"

# A LIBEXECS goes to $PREFIX/libexec rather than $PREFIX/bin, a nested
# name keeps its directory there, and a bash one goes the same place a
# compiled one does.  The program that runs it finds it through
# __PCONFIGURE__LIBEXEC, which has to name the directory it was
# installed into.  "make uninstall" takes all of them back out.
mkdir -p src
echo 'int main(void) { return 0; }' > src/helper.c
echo 'echo helping' > src/helper-script.bash
cat >src/main.c <<'EOF2'
#include <stdio.h>
int main(void) { puts(__PCONFIGURE__LIBEXEC); return 0; }
EOF2

cat >Configfile <<EOF2
PREFIX     = $tempdir/opt/thing
LANGUAGES += c
LANGUAGES += bash

LIBEXECS  += helper
SOURCES   += helper.c

LIBEXECS  += tools/helper-script
SOURCES   += helper-script.bash

BINARIES  += main
SOURCES   += main.c
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS install

find opt -type f | sort > installed
cat installed
cat >expected <<EOF2
opt/thing/bin/main
opt/thing/libexec/helper
opt/thing/libexec/tools/helper-script
EOF2
diff -u expected installed

test "$($tempdir/opt/thing/bin/main)" = "$tempdir/opt/thing/libexec"
test -x "$($tempdir/opt/thing/bin/main)/helper"
test "$(bash $tempdir/opt/thing/libexec/tools/helper-script)" = "helping"

make $MAKE_ARGS uninstall
test -z "$(find opt -type f)"
