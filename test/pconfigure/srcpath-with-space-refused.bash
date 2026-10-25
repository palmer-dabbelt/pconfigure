#include "harness_start.bash"

# --srcpath naming a directory with a space in it.  This used to be
# taken, with the warning written for a list of files -- "write one
# SRCPATH line per file" -- which is no help for a directory, and then
# a Makefile came out in which every source path was split at the
# space, so make stopped on "No rule to make target '../my'".  The
# source root is on the front of every target the Makefile names, so
# there was never a build there to keep working: it's refused up
# front, the way a PREFIX with a space is, and no Makefile is written.
mkdir -p "my tree/src" build
echo 'int main(void) { return 0; }' > "my tree/src/hello.c"
cat >"my tree/Configfile" <<'EOF2'
LANGUAGES += c
BINARIES  += hello
SOURCES   += hello.c
EOF2

cd build
if $PTEST_BINARY --srcpath "../my tree" > out 2>&1
then
    cat out
    echo "a --srcpath with a space in it was accepted" >&2
    exit 1
fi
cat out

test ! -e Makefile
grep -q -- "--srcpath ../my tree" out
grep -q "error:" out
grep -q "whitespace" out

# The list-of-files advice is about something a source tree isn't, so
# it has no business coming out ahead of the error.
if grep -q "one SRCPATH line per file" out
then
    exit 1
fi
cd ..

# The same directory named by a SRCPATH line in a Configfile, which
# reaches the same code by the other door and should be pointed at by
# its line.
mkdir -p outer
cat >outer/Configfile <<'EOF2'
SRCPATH = ../my tree
EOF2
cd outer
if $PTEST_BINARY > out 2>&1
then
    cat out
    echo "a SRCPATH with a space in it was accepted" >&2
    exit 1
fi
cat out

test ! -e Makefile
grep -q "Configfile:1" out
grep -q "error:" out
