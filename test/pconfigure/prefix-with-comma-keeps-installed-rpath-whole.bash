#include "harness_start.bash"

# The installed flavour of a program is linked with an rpath of
# "$PREFIX/lib", which went on the link line as "-Wl,-rpath,..."  --
# and the compiler driver splits a "-Wl," argument at every comma.  A
# PREFIX of "/opt/app,v2" therefore handed the linker an rpath of
# "/opt/app" and an input file "v2/lib", and "make install" failed on
# "cannot find v2/lib" without a word about the Configfile.  The plain
# build worked, since the tree's copy has an $ORIGIN rpath instead, so
# this only ever showed up when somebody installed.  A comma means
# nothing to make, the shell or the linker, so the PREFIX is fine as
# it is: the program installs with exactly the rpath it was given.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfile <<'EOF2'
PREFIX     = /opt/app,v2
LANGUAGES += c
BINARIES  += main
SOURCES   += main.c
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS

make $MAKE_ARGS
make $MAKE_ARGS DESTDIR=$tempdir/dest install
test -x dest/opt/app,v2/bin/main
readelf -d dest/opt/app,v2/bin/main | grep -F '[/opt/app,v2/lib]'
