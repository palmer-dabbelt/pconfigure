#include "harness_start.bash"

# pconfigure names the helper tools it writes into recipes -- pbashc
# to build a script, pdeps to keep its includes current -- by the
# absolute path of the directory it was run from.  A pconfigure that
# lives under a directory with a space in it, which ppkg-config was
# already taught to cope with, has to write those paths so the shell
# reads each as one word, or the first make runs "/.../my" and stops
# on "No such file or directory".
#
# The tools are copied with the libraries beside them, which is the
# layout the binaries' $ORIGIN runpath expects.

here_bin="$(dirname "$PTEST_BINARY")"
mkdir -p "my tools/bin" "my tools/lib"
cp "$here_bin"/* "my tools/bin/"
cp "$here_bin"/../lib/*.so "my tools/lib/"
pconfigure="$(pwd)/my tools/bin/pconfigure"
test -x "$pconfigure"

mkdir -p src

cat >Configfile <<'EOC'
LANGUAGES   += bash
BINARIES    += hello
SOURCES     += hello.bash
EOC

cat >src/hello.bash <<'EOC'
#!/bin/bash
#include "greeting.bash"
greet
EOC

echo 'greet() { echo hello; }' > src/greeting.bash

"$pconfigure" $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/hello)" = "hello"
