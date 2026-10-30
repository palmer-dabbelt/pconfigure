#include "harness_start.bash"

# A make -j install into a DESTDIR that doesn't exist yet has every
# install rule racing to create the same few directories, and the
# install-flavoured links racing the tree's links of the same targets.
# Each install is copied to a temporary name and moved into place, and
# each directory is made with mkdir -p, so the order they land in
# can't matter.  Run a few times from clean to give an ordering
# problem a chance to show.

mkdir -p src include

echo 'int v(void) { return 7; }' > src/v.c
echo 'int w(void) { return 8; }' > src/w.c
echo 'int v(void);' > include/v.h
printf '#!/bin/bash\necho script\n' > src/s.bash
cat >src/main.c <<'EOS'
#include <stdio.h>
#include "v.h"
int w(void);
int main(void) { printf("%d\n", v() + w()); return 0; }
EOS

cat >Configfile <<'EOC'
LANGUAGES += c
LANGUAGES += bash

LIBRARIES += libv.so
SOURCES   += v.c

LIBRARIES += libw.a
SOURCES   += w.c

HEADERS   += v.h

BINARIES  += app
DEPLIBS   += v
DEPLIBS   += w
SOURCES   += main.c

BINARIES  += s
SOURCES   += s.bash
EOC

$PTEST_BINARY $PCONFIGURE_ARGS

for round in 1 2 3
do
    make $MAKE_ARGS clean
    rm -rf stage
    make $MAKE_ARGS -j8 install DESTDIR="$(pwd)/stage"
    [ "$(uname -s)" = "Darwin" ] && install_name_tool -add_rpath "$(pwd)/stage/usr/local/lib" stage/usr/local/bin/app

    test -x stage/usr/local/bin/app
    test -x stage/usr/local/bin/s
    test -e stage/usr/local/lib/libv.so
    test -e stage/usr/local/lib/libw.a
    diff -u include/v.h stage/usr/local/include/v.h
    test "$(LD_LIBRARY_PATH=stage/usr/local/lib ./stage/usr/local/bin/app)" = "15"
    test "$(./stage/usr/local/bin/s)" = "script"

    # Nothing half-written was left behind under a temporary name.
    test -z "$(find stage -name '*.tmp*')"
done

# And the -j build left nothing for a second install to do.
make $MAKE_ARGS -q install DESTDIR="$(pwd)/stage"
