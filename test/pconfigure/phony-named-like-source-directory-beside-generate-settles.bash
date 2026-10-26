#include "harness_start.bash"

# "make src" is a natural PHONY to want.  But a GENERATE's dependency
# fragment watches the directory its script sits in -- so that a file
# appearing there is noticed -- and that directory is "src".  Named
# bare, a "src" in .PHONY was out of date on every look, so the
# fragment was remade, make re-executed itself because the fragment is
# an included makefile, found it out of date again, and printed
# "DEPS gen.h" forever on a plain "make".  The name is fine; the build
# has to finish, and a second make has nothing left to do.

mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES += c

GENERATE  += gen.h

BINARIES  += hello
SOURCES   += hello.c

PHONY     += src
EOF2

cat >src/gen.h.proc <<'EOF2'
#!/bin/bash
if test "$1" = "--deps"
then
    exit 0
fi
echo "#define X 0"
EOF2
chmod +x src/gen.h.proc

cat >src/hello.c <<'EOF2'
#include "gen.h"
int main(void) { return X; }
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS

timeout 60 make $MAKE_ARGS > make.out 2>&1 || { tail -20 make.out; exit 1; }
cat make.out
test "$(grep -c "^DEPS	gen.h$" make.out)" -le 1
./bin/hello

timeout 60 make $MAKE_ARGS > again.out 2>&1 || { tail -20 again.out; exit 1; }
cat again.out
grep -q "Nothing to be done" again.out
! grep -q "^DEPS" again.out

# The PHONY itself still answers to its name.
timeout 60 make $MAKE_ARGS src

# And the directory is still watched: a file arriving in it rederives
# the fragment once, and then the build settles again.
touch src/new-input
timeout 60 make $MAKE_ARGS > third.out 2>&1 || { tail -20 third.out; exit 1; }
cat third.out
test "$(grep -c "^DEPS	gen.h$" third.out)" -eq 1
timeout 60 make $MAKE_ARGS > fourth.out 2>&1 || { tail -20 fourth.out; exit 1; }
grep -q "Nothing to be done" fourth.out
