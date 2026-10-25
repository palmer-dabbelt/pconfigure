#include "harness_start.bash"

# Both copies of a .pc that make builds name a record of the recipe
# that builds them, so that a new PREFIX, sed option or template
# rebuilds them.  That record must only ever be newer than the .pc
# when it says something different: a reconfigure that changes
# nothing has to leave the built and installed copies alone, and so
# does the first configure that writes a record beside a .pc built
# before records were kept.
mkdir -p src

cat >src/x.pc <<'EOF2'
prefix=@@pconfigure_prefix@@
Name: x
Description: x
Version: @@VERSION@@
EOF2

cat >Configfile <<'EOF2'
LANGUAGES   += pkgconfig
LIBRARIES   += pkgconfig/x.pc
COMPILEOPTS += s/@@VERSION@@/1.0/
SOURCES     += x.pc
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS DESTDIR=$tempdir/dest install
grep -q "^Version: 1.0$" lib/pkgconfig/x.pc
grep -q "^Version: 1.0$" dest/usr/local/lib/pkgconfig/x.pc

# Judged by the files themselves rather than by what make prints,
# since the short "PKGCFG" label is only printed in quiet mode.
unchanged() {
    sleep 1
    touch settled.stamp
    $PTEST_BINARY $PCONFIGURE_ARGS
    make $MAKE_ARGS
    make $MAKE_ARGS DESTDIR=$tempdir/dest install
    if test -n "$(find lib dest -name x.pc -newer settled.stamp)"
    then
        echo "$1 rebuilt the .pc" >&2
        exit 1
    fi
}

unchanged "a reconfigure that changed nothing"

# What a tree whose object directory has never had a record in it
# looks like, with the .pc built and up to date beside it.
find obj -name '*.recipe-inputs' -delete
unchanged "the first record of an up-to-date .pc"
test -n "$(find obj -name '*.recipe-inputs')"

exit 0
