#include "harness_start.bash"

# What "make cache-clean" is for: a source that has left the
# Configfile leaves its object behind, since "make clean" only takes
# what the current Makefile names.  The cache-clean takes that object
# and nothing else -- the objects still in use stay, so the build
# after it relinks nothing.
mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

BINARIES  += app
SOURCES   += app.c
SOURCES   += gone.c
EOF

echo 'int main(void) { return 0; }' > src/app.c
echo 'int gone(void) { return 1; }' > src/gone.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
ls obj/src/gone.c/*.o

cat >Configfile <<EOF
LANGUAGES += c

BINARIES  += app
SOURCES   += app.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
ls obj/src/app.c/*.o > kept.before
stat -c '%n %Y' obj/src/app.c/*.o bin/app > stamps.before

make $MAKE_ARGS cache-clean

# The stale object is gone, and so is the directory it left empty.
test ! -e obj/src/gone.c

# The live object is still there.
ls obj/src/app.c/*.o > kept.after
diff -u kept.before kept.after

# Neither it nor the program is rebuilt afterwards.  The one-second
# step makes a rebuild show up as a newer modification time.
sleep 1
make $MAKE_ARGS > after.out 2>&1
cat after.out
grep -q "Nothing to be done" after.out
stat -c '%n %Y' obj/src/app.c/*.o bin/app > stamps.after
diff -u stamps.before stamps.after

exit 0
