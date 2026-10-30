#include "harness_start.bash"

# Every object is compiled with -D__PCONFIGURE__PREFIX naming the
# install prefix, so a program can find its own data once installed.
# An object's directory is named after a hash of its compile options,
# which is what makes a COMPILEOPTS change recompile it
# (compileopts-change-recompiles-objects.bash).  That only works for an
# option the hash covers, and a hash taken over what the Configfile
# said rather than over the whole compile line misses the -D pconfigure
# adds itself: moving PREFIX would leave the object, and the string
# baked into it, where they were.

export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src

cat >src/main.c <<'EOF'
#include <stdio.h>
int main(void) { printf("%s\n", __PCONFIGURE__PREFIX); return 0; }
EOF

cat >Configfile <<EOF
AUTORECONFIGURE = true
PREFIX          = /opt/one

LANGUAGES += c

BINARIES  += app
SOURCES   += main.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "/opt/one"

sleep 2
sed -i.bak 's@/opt/one@/opt/two@' Configfile

make $MAKE_ARGS
test "$(./bin/app)" = "/opt/two"
