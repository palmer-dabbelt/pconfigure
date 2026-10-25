#include "harness_start.bash"

# Under AUTORECONFIGURE a script's includes are listed in a stamp that
# pdeps writes, and the fragment pdeps writes beside it has a rule to
# put the stamp back when it is missing.  That rule runs pdeps by the
# absolute path it was configured with, and it is written by pdeps
# rather than pconfigure, so it needs the quoting of its own: the first
# build never runs it, only a build that finds the stamp gone does.
# With the tools under a directory with a space in it, that build ran
# "/.../my" and stopped with exit 127.

here_bin="$(dirname "$PTEST_BINARY")"
mkdir -p "my tools/bin" "my tools/lib"
cp "$here_bin"/* "my tools/bin/"
cp "$here_bin"/../lib/*.so "my tools/lib/"
pconfigure="$(pwd)/my tools/bin/pconfigure"
test -x "$pconfigure"

mkdir -p src

cat >Configfile <<'EOC'
AUTORECONFIGURE  = true
LANGUAGES       += bash
BINARIES        += hello
SOURCES         += hello.bash
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

# The stamp is found rather than spelled out, so this test does not
# pin down how the object directory is laid out.
stamps="$(find obj -name '*-script.d.includes')"
test -n "$stamps"
rm -f $stamps

make $MAKE_ARGS
test "$(./bin/hello)" = "hello"
test -n "$(find obj -name '*-script.d.includes')"
