#include "harness_start.bash"

# The other half of the cmake build system: with a generator that
# isn't a make, the build-time install is a "cmake --build --target
# install", which no MAKEFLAGS reaches.  The environment does, though,
# and make puts every variable from its command line into the
# environment of the recipes it runs -- so "make DESTDIR=/stage" is
# still a DESTDIR the cmake_install.cmake script reads, and the tree
# still installs under /stage/<absolute object prefix> while
# obj/sub/prefix stays empty.

if ! command -v cmake > /dev/null || ! command -v ninja > /dev/null
then
    echo "SKIP: no cmake or no ninja on the PATH"
    exit 0
fi

mkdir -p sub

cat >Configfile <<'EOF2'
BUILD_SYSTEMS += cmake
CONFIGUREOPTS += --generator Ninja
SUBPROJECTS   += sub
EOF2

cat >sub/CMakeLists.txt <<'EOF2'
cmake_minimum_required(VERSION 3.10)
project(sub NONE)
file(WRITE ${CMAKE_BINARY_DIR}/tool.txt "tool\n")
install(FILES ${CMAKE_BINARY_DIR}/tool.txt DESTINATION share)
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS DESTDIR="$tempdir/stage"

test -f obj/sub/prefix/share/tool.txt
test ! -e "$tempdir/stage"

exit 0
