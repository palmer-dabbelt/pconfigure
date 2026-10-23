#include "harness_start.bash"

# "LIBDIR =" with nothing after it is refused, and the reason is
# written down beside the refusal in command.c++: an empty LIBDIR
# quietly makes every library path in the build absolute, so the
# library this project builds lands at "/libfoo.so" -- and "make
# clean" is an "rm -fr" of it.
#
# A backtick that prints nothing is the same line by the time anything
# reads it, and has to get the same answer.  An empty answer from a
# command is the usual way a script says "I don't know": the variable
# it echoes isn't set, the file it cats isn't there.  The refusal is
# what a project needs here, not a Makefile that writes into the root
# of the filesystem.
mkdir -p src
echo 'int foo(void) { return 0; }' > src/foo.c

cat >Configfile <<'EOF'
LANGUAGES   += c

LIBDIR       = `true`
LIBRARIES   += libfoo.so
SOURCES     += foo.c
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    cat Makefile
    echo "LIBDIR set to nothing by a backtick was accepted" >&2
    exit 1
fi
cat out
grep -q "Configfile:3" out
grep -q "printed nothing" out
test ! -e Makefile

# And the same with a command that printed nothing but whitespace,
# which is a nothing too once the line has been tidied.
rm -f out
cat >Configfile <<'EOF'
LANGUAGES   += c

LIBDIR       = `echo "   "`
LIBRARIES   += libfoo.so
SOURCES     += foo.c
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    echo "LIBDIR set to whitespace by a backtick was accepted" >&2
    exit 1
fi
cat out
grep -q "Configfile:3" out
grep -q "printed nothing" out
test ! -e Makefile
