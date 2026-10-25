#include "harness_start.bash"

# "make reconfigure" runs the pconfigure that wrote the Makefile, named
# by where it was run from rather than by $PATH.  A pconfigure under a
# directory with a space in its name -- "my tools/bin", or a home
# directory on a machine that allows that -- has to be written so the
# shell reads that path as one word, or the rule runs "/x/my" instead.
# ppkg-config-beside-pconfigure-in-spaced-directory.bash is the
# backtick spelling of the same path; this is the recipe spelling.

here_bin="$(dirname "$PTEST_BINARY")"
mkdir -p "my tools/bin" "my tools/lib"
cp "$here_bin"/* "my tools/bin/"
cp "$here_bin"/../lib/*.so "my tools/lib/"
pconfigure="$(pwd)/my tools/bin/pconfigure"
test -x "$pconfigure"

mkdir -p src
echo 'int main(void) { return 0; }' > src/hello.c
cat >Configfile <<'EOC'
LANGUAGES += c
BINARIES  += hello
SOURCES   += hello.c
EOC

"$pconfigure" $PCONFIGURE_ARGS
make $MAKE_ARGS
test -x bin/hello

echo 'BINARIES += two' >> Configfile
echo 'SOURCES  += hello.c' >> Configfile
make $MAKE_ARGS reconfigure > reconfigure.out 2>&1 || { cat reconfigure.out; exit 1; }
cat reconfigure.out
grep -q '^bin/two:' Makefile
