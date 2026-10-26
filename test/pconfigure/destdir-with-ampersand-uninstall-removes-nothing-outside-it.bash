#include "harness_start.bash"

# A staging directory under a checkout called "R&D" is an ordinary
# directory name, and the Makefile already refuses the DESTDIR
# characters make itself trips over (whitespace, ':', ';', '%').  An
# '&' gets past that, and every uninstall rule pastes $(DESTDIR) bare
# into "rm -f $(DESTDIR)/usr/local/bin/hello" -- where the shell reads
# the '&' as the end of one command run in the background.  What runs
# is "rm -f .../R", deleting a file that has nothing to do with the
# install, and only then the half that fails.  Whatever make uninstall
# does with a DESTDIR like this, it may only ever remove things inside
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
echo "unrelated" > R

# An uninstall that went through had nothing to remove; one that
# didn't has to say DESTDIR is why rather than leave the shell's
# complaint about a line of the Makefile.
if ! make $MAKE_ARGS uninstall DESTDIR="$destdir" > uninstall.out 2>&1
then
    grep -F "DESTDIR=\"$destdir\"" uninstall.out
fi
cat uninstall.out

test -f R
test "$(cat R)" = "unrelated"

exit 0
