#include "harness_start.bash"

# A library dropped from the Configfile keeps its lib/libold.so after
# a make clean, since the clean rules are written from the Configfile
# as it is now.  That copy is worse than clutter: lib/ is the first
# place every link in the tree searches, so a LINKOPTS += -lold left
# behind goes on linking against a library the build no longer makes,
# and keeps doing so through every clean.

mkdir -p src

echo 'int old(void) { return 0; }' > src/old.c
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfile <<'EOC'
LANGUAGES += c
LIBRARIES += libold.so
SOURCES   += old.c
BINARIES  += app
SOURCES   += main.c
EOC

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test -e lib/libold.so

cat >Configfile <<'EOC'
LANGUAGES += c
BINARIES  += app
SOURCES   += main.c
EOC

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS clean

test ! -e bin/app
test ! -e lib/libold.so
