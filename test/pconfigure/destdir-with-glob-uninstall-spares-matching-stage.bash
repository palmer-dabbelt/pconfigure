#include "harness_start.bash"

# A '?', '*' or '[' is a legal character in a directory name, and
# "make uninstall" is an "rm -f $(DESTDIR)/..." per installed file
# with $(DESTDIR) pasted in bare.  The shell globs that word before rm
# sees it, and a pattern that matches nothing is passed through as it
# was written -- so installing into "st?ge" looked fine, but
# uninstalling from it removed the files of "stage", a staging
# directory that was installed separately and never named, because
# "st?ge/usr/local/bin/main" matches it.  Either the uninstall leaves
# "stage" alone or it is refused in words naming DESTDIR.
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

for destdir in "$tempdir/st?ge" "$tempdir/st*" "$tempdir/st[a]ge"
do
    if ! make $MAKE_ARGS DESTDIR="$destdir" uninstall > uninstall.out 2>&1
    then
        grep -F "DESTDIR=\"$destdir\"" uninstall.out
    fi
    cat uninstall.out

    test -x stage/usr/local/bin/main
    test -f stage/usr/local/include/main.h
done
