#include "harness_start.bash"

# The tools pconfigure writes into recipes are named by the absolute
# path it was run from.  A '#' in that path is a comment to make on a
# rule line, but these paths only ever reach recipe lines, which make
# hands to the shell without looking for comments -- and the shell
# reads a '#' in the middle of a word as part of the word.  So a
# pconfigure under "tools#1" builds a script, runs a test and keeps a
# C build's dependencies current like any other.

tooldir='tools#1'
here_bin="$(dirname "$PTEST_BINARY")"
mkdir -p "$tooldir/bin" "$tooldir/lib"
cp "$here_bin"/* "$tooldir/bin/"
cp "$here_bin"/../lib/*.so "$tooldir/lib/"
pconfigure="$(pwd)/$tooldir/bin/pconfigure"
test -x "$pconfigure"

mkdir -p src test/main

echo '#define VALUE 0' > src/value.h
cat >src/main.c <<'EOC'
#include "value.h"
int main(void) { return VALUE; }
EOC

cat >src/hello.bash <<'EOC'
#!/bin/bash
echo hello
EOC

cat >test/main/passes.bash <<'EOC'
#!/bin/bash
exit 0
EOC

cat >Configfile <<'EOC'
AUTORECONFIGURE  = true
LANGUAGES       += c
LANGUAGES       += bash
BINARIES        += main
SOURCES         += main.c
TESTSRC         += passes.bash
BINARIES        += hello
SOURCES         += hello.bash
EOC

"$pconfigure" $PCONFIGURE_ARGS
grep -qF "$tooldir/bin/" Makefile
make $MAKE_ARGS
./bin/main
test "$(./bin/hello)" = "hello"
make $MAKE_ARGS check
test "$(tar -xOf check/main/passes.bash ptest__return)" = 0

sleep 1
echo '#define VALUE 3' > src/value.h
make $MAKE_ARGS
set +e
./bin/main
status=$?
set -e
test "$status" = 3
