#include "harness_start.bash"

# make reads a '|' in a rule's prerequisite list as the start of the
# order-only prerequisites, and every installed file is a prerequisite
# of "install" spelled with $(DESTDIR) on the front.  A DESTDIR with a
# '|' in it cut the name in two and stopped make on "No rule to make
# target '.../st', needed by 'install'", which names a path nobody
# wrote and says nothing about DESTDIR.  A ':' and a ';' break the
# same rule line and are refused with a sentence naming DESTDIR; a '|'
# needs the same.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfile <<'EOF2'
LANGUAGES += c

BINARIES  += main
SOURCES   += main.c
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

destdir="$tempdir/st|age"
if make $MAKE_ARGS DESTDIR="$destdir" install > install.out 2>&1
then
    cat install.out
    test -x "$destdir/usr/local/bin/main"
else
    cat install.out
    grep -F "DESTDIR=\"$destdir\"" install.out
fi
test ! -e "$tempdir/st"

if make $MAKE_ARGS DESTDIR="$destdir" uninstall > uninstall.out 2>&1
then
    cat uninstall.out
    test ! -e "$destdir/usr/local/bin/main"
else
    cat uninstall.out
    grep -F "DESTDIR=\"$destdir\"" uninstall.out
fi
