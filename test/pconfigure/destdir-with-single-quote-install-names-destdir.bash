#include "harness_start.bash"

# "make install DESTDIR=$HOME/Bob's stage" minus the space, which is
# refused already: a single quote in a staging directory.  Every
# install recipe pastes $(DESTDIR) in bare, and the shell reads the
# quote as the start of a string that never ends, so the install
# stops on "unexpected EOF while looking for matching quote" -- an
# error about the recipe rather than about DESTDIR.  The install has
# to land in the named directory or say DESTDIR is what is wrong.

mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES += c

BINARIES  += hello
SOURCES   += hello.c
EOF2

echo 'int main(void) { return 0; }' > src/hello.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

destdir="$tempdir/bob's-stage"
if make $MAKE_ARGS install DESTDIR="$destdir" > install.out 2>&1
then
    cat install.out
    test -x "$destdir/usr/local/bin/hello"
else
    cat install.out
    grep -F "DESTDIR=\"$destdir\"" install.out
    test ! -e "$destdir"
fi

exit 0
