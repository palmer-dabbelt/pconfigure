#include "harness_start.bash"

# The compiled half of install-modes-ignore-build-umask: a program and
# a shared library came out 0755 already, but only because the
# install flavour of each is linked during the install itself, under
# whatever umask that runs with.  A static archive has one flavour,
# archived during the build, and was copied as it stood -- so a tree
# built under "umask 077" installed it as -rw------- and nobody else
# could link against it.  Every install copy now sets the mode
# "install -m" would, rather than leaning on when the file was made.
(
    umask 077
    mkdir -p src
    echo 'int main(void) { return 0; }' > src/main.c
    echo 'int shared(void) { return 0; }' > src/shared.c
    echo 'int archived(void) { return 0; }' > src/archived.c

    cat >Configfile <<'EOF2'
LANGUAGES += c

BINARIES  += main
SOURCES   += main.c

LIBRARIES += libshared.so
SOURCES   += shared.c

LIBRARIES += libarchived.a
SOURCES   += archived.c
EOF2

    $PTEST_BINARY $PCONFIGURE_ARGS
    make $MAKE_ARGS
)

umask 022
make $MAKE_ARGS DESTDIR=$tempdir/dest install
ls -l dest/usr/local/bin dest/usr/local/lib

test -n "$(find dest/usr/local/bin/main -perm 0755)"
test -n "$(find dest/usr/local/lib/libshared.so -perm 0755)"
test -n "$(find dest/usr/local/lib/libarchived.a -perm 0644)"

# An install with a looser umask than 022 still gets exactly those
# modes, rather than a group-writable library.
rm -rf dest
umask 002
make $MAKE_ARGS DESTDIR=$tempdir/dest install
test -n "$(find dest/usr/local/bin/main -perm 0755)"
test -n "$(find dest/usr/local/lib/libshared.so -perm 0755)"
test -n "$(find dest/usr/local/lib/libarchived.a -perm 0644)"
