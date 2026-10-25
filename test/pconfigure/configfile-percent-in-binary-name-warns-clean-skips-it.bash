#include "harness_start.bash"

# A '%' in a target's name builds: "bin/50%off:" is a pattern rule,
# and "all: bin/50%off" happens to match it with a stem of "%".  The
# rules that clean and uninstall it are phony targets with the same
# '%' in their names, though, and make never looks for a pattern rule
# for a phony target -- so "make clean" and "make uninstall" find
# nothing to do, say nothing, and leave the program built and
# installed.  A project that has one of these is relying on it
# building, so it's a warning rather than a refusal, and it has to
# name the line and say what goes wrong.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += c

BINARIES  += 50%off
SOURCES   += main.c
EOF

cat >src/main.c <<'EOF'
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
cat configure.out
grep -q "Configfile:3" configure.out
grep -qF "warning: BINARIES has a '%' in it: '50%off'" configure.out
grep -q "make clean" configure.out
grep -q "make uninstall" configure.out
grep -q "'STRICT = v0.13' makes this an error" configure.out

# Only the one line: the SOURCES under it is an ordinary name.
test "$(grep -c "warning:" configure.out)" = 1

# The warning is all that changed.  What built and installed before
# still does, which is the promise a warning is made to keep.
make $MAKE_ARGS
test -x 'bin/50%off'
make $MAKE_ARGS install DESTDIR="$tempdir/stage"
test -x 'stage/usr/local/bin/50%off'

# A project that asked to be told loudly is stopped at the line, with
# no Makefile left behind to build the thing that was refused.
mkdir -p strict/src
cp src/main.c strict/src/
cat >strict/Configfile <<'EOF'
STRICT     = v0.13
LANGUAGES += c

BINARIES  += 50%off
SOURCES   += main.c
EOF

if (cd strict && $PTEST_BINARY $PCONFIGURE_ARGS) > strict.out 2>&1
then
    cat strict.out
    exit 1
fi
cat strict.out
grep -q "Configfile:4" strict.out
grep -qF "error: BINARIES has a '%' in it" strict.out
test ! -e strict/Makefile

exit 0
