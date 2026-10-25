#include "harness_start.bash"

# "make check" runs ptest, named by the absolute path of the directory
# pconfigure was run from.  When that directory has a space in it the
# path has to reach the shell as one word, or every test result and
# the report after them stop on "No such file or directory" -- in a
# project whose own paths have no space anywhere.

here_bin="$(dirname "$PTEST_BINARY")"
mkdir -p "my tools/bin" "my tools/lib"
cp "$here_bin"/* "my tools/bin/"
cp "$here_bin"/../lib/*.so "my tools/lib/"
pconfigure="$(pwd)/my tools/bin/pconfigure"
test -x "$pconfigure"

mkdir -p src test/main

echo 'int main(void) { return 0; }' > src/main.c

cat >test/main/passes.bash <<'EOC'
#!/bin/bash
exit 0
EOC

cat >Configfile <<'EOC'
LANGUAGES   += c
LANGUAGES   += bash
BINARIES    += main
SOURCES     += main.c
TESTSRC     += passes.bash
EOC

"$pconfigure" $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS check
