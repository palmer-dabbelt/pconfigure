#include "harness_start.bash"

# Half of an object directory is no different from all of it.
# "obj/bin" holds the links' intermediate outputs, which any build
# remakes, and next to them the per-link files pconfigure writes when
# it runs -- the record of a link's inputs, and under AUTORECONFIGURE
# the context pdeps reads.  Deleting the directory to force the links
# again is the natural thing to try, and it should do exactly that.

export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src

cat >Configfile <<'EOF'
AUTORECONFIGURE  = true
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
EOF

echo 'int main(void) { return 0; }' > src/main.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test -x bin/main

rm -rf obj/bin

make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
test -x bin/main

# And it settles, so whatever brought the files back is not something
# every make goes on doing.
make $MAKE_ARGS > settled.log 2>&1 || { cat settled.log; exit 1; }
cat settled.log
grep -q "Nothing to be done" settled.log

exit 0
