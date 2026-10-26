#include "harness_start.bash"

# "make uninstall" is an "rm -f $(DESTDIR)/..." per installed file,
# and the shell drops the backslash out of a DESTDIR of 'st\age'
# before rm sees it -- so uninstalling from one staging directory
# deleted the files of a different one, "stage", which had been
# installed separately and was never named.  An uninstall that can't
# spell its DESTDIR has to say so rather than remove somebody else's
# files.
mkdir -p src include
echo 'int main(void) { return 0; }' > src/main.c
echo 'int f(void);' > include/main.h

cat >Configfile <<'EOF2'
LANGUAGES += c

BINARIES  += main
SOURCES   += main.c

HEADERS   += main.h
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS DESTDIR="$tempdir/stage" install
test -x stage/usr/local/bin/main
test -f stage/usr/local/include/main.h

destdir="$tempdir/st\\age"
if ! make $MAKE_ARGS DESTDIR="$destdir" uninstall > uninstall.out 2>&1
then
    grep -F "DESTDIR=\"$destdir\"" uninstall.out
fi
cat uninstall.out

test -x stage/usr/local/bin/main
test -f stage/usr/local/include/main.h
