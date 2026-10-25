#include "harness_start.bash"

# The tools pconfigure names in recipes are spelled by the absolute
# path it was run from, and a recipe is expanded by make before the
# shell sees it.  A '$' in that directory's name -- "tools$x" -- is a
# variable to make, so pbashc and ptest are looked for in
# ".../tools/bin" and "make check" stops on "No such file or
# directory".  The directory is only text to pconfigure and has to
# reach the shell as text.

tooldir='tools$x'
here_bin="$(dirname "$PTEST_BINARY")"
mkdir -p "$tooldir/bin" "$tooldir/lib"
cp "$here_bin"/* "$tooldir/bin/"
cp "$here_bin"/../lib/*.so "$tooldir/lib/"
pconfigure="$(pwd)/$tooldir/bin/pconfigure"
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
