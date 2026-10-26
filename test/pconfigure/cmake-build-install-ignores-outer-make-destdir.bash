#include "harness_start.bash"

# A vendored cmake tree is installed into its object-directory prefix
# as part of building it, by the cmake_install.cmake script cmake
# generates -- which reads DESTDIR from the environment.  make exports
# a variable from its command line to every recipe, so "make
# DESTDIR=/stage" sends the build-time install to
# /stage/<absolute object prefix> while the stamp records it as done.
# pconfigure refuses DESTDIR as a --define, --configure-arg, MAKEOPS
# and --env for this reason; the command line gets it through anyway.

if ! command -v cmake > /dev/null
then
    echo "SKIP: no cmake on the PATH"
    exit 0
fi

mkdir -p sub

cat >Configfile <<'EOF2'
BUILD_SYSTEMS += cmake
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
