#include "harness_start.bash"

# An object directory is a cache: it holds what the build made, and
# deleting it should cost a rebuild and nothing more.  pconfigure also
# keeps a few files of its own in there, written when it runs rather
# than by any rule -- the file that records what goes into each link is
# one -- and a link rule names that file as a prerequisite.  With the
# directory gone, a prerequisite nothing has a rule for is "No rule to
# make target" on every make after, in a tree whose Configfiles say
# exactly what they said before.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
EOF

echo 'int main(void) { return 0; }' > src/main.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test -x bin/main

rm -rf obj bin

make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
test -x bin/main

# And it settles, so whatever brought the files back is not something
# every make goes on doing.
make $MAKE_ARGS > settled.log 2>&1 || { cat settled.log; exit 1; }
cat settled.log
grep -q "Nothing to be done" settled.log

exit 0
