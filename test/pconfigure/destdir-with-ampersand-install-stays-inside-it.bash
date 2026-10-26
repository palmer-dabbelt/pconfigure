#include "harness_start.bash"

# "make install DESTDIR=$PWD/R&D/stage" from a checkout under a
# directory called "R&D".  The Makefile stops on a DESTDIR with a
# ':', ';' or '%' with a sentence naming DESTDIR, but an '&' goes
# straight into "mkdir -p $(DESTDIR)/usr/local/bin/", where the shell
# runs "mkdir -p .../R" in the background and then tries to run
# "D/stage/..." as a command.  The install either has to land in the
# directory that was named or stop with an error that says DESTDIR is
# the problem -- and either way it must not create anything beside
# it.

mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES += c

BINARIES  += hello
SOURCES   += hello.c
EOF2

echo 'int main(void) { return 0; }' > src/hello.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

mkdir "R&D"
destdir="$tempdir/R&D/stage"
if make $MAKE_ARGS install DESTDIR="$destdir" > install.out 2>&1
then
    cat install.out
    test -x "$destdir/usr/local/bin/hello"
else
    cat install.out
    grep -F "DESTDIR=\"$destdir\"" install.out
fi

# The text before the '&' is not a directory anybody asked for.
test ! -e R

exit 0
