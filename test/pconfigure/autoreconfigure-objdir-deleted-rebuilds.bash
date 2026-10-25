#include "harness_start.bash"

# Under AUTORECONFIGURE the build already comes back from a deleted
# subproject object directory, by re-running pconfigure for the
# Makefile that went with it: the manual's reason is that an object
# directory is a thing people delete.  The top project's own object
# directory is no less deletable, and it holds the context files pdeps
# reads, which pconfigure writes and no rule makes.  Without them every
# fragment's rule stops on "No rule to make target", on this make and
# every one after it.

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

rm -rf obj

make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
test -x bin/main

# And it settles, so whatever brought it back is not something every
# make goes on doing.
make $MAKE_ARGS > third.log 2>&1
cat third.log
grep -q "Nothing to be done" third.log

exit 0
