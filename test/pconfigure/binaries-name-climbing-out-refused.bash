#include "harness_start.bash"

# A BINARIES name is a path as much as a SOURCES is: it is pasted onto
# the binary directory to say where the program is copied, onto the
# object directory to say where it is linked, and onto
# "$(DESTDIR)/$PREFIX/bin" to say where "make install" puts it.  So a
# name that climbs out of the project lands a program outside it --
# "../../evil" is linked into a directory beside the checkout and
# installed into "$PREFIX/../evil" -- and "make clean" and "make
# uninstall" then go and remove whatever is at those paths.  The same
# question SOURCES is asked has to be asked of the target's own name.
mkdir -p proj/src
echo 'int main(void) { return 0; }' > proj/src/main.c

for name in "../../evil" ".." "/tmp/evil"
do
    cat >proj/Configfile <<EOF
LANGUAGES += c

BINARIES  += $name
SOURCES   += main.c
EOF
    cat proj/Configfile
    rm -f proj/Makefile

    if (cd proj && $PTEST_BINARY $PCONFIGURE_ARGS) > out 2>&1
    then
        cat out
        echo "BINARIES += $name was accepted" >&2
        exit 1
    fi
    cat out

    # The refusal points at the line and says which spelling it was,
    # the same way every other path refusal does.
    grep -q "Configfile:3" out
    grep -q "it climbs out of the project\|it's an absolute path" out
    test ! -e proj/Makefile
done

# Nothing landed beside the project either, which is the half of
# this that matters to whoever owns the directory above it.
test ! -e evil

# A name with a directory in it is still a name inside the project --
# "tools/run" is a program in bin/tools -- and the refusal above is
# about where a name ends up, not about whether it has a slash in it.
# So the spelling that has to keep working is built and installed
# here too, next to the ones that mustn't.
cat >proj/Configfile <<EOF
LANGUAGES += c

BINARIES  += tools/run
SOURCES   += main.c
EOF
cat proj/Configfile
(cd proj && $PTEST_BINARY $PCONFIGURE_ARGS)
(cd proj && make $MAKE_ARGS)
test -x proj/bin/tools/run
(cd proj && make $MAKE_ARGS DESTDIR=$tempdir/dest install)
find $tempdir/dest -type f
test -n "$(find $tempdir/dest -path '*/bin/tools/run' -type f)"
