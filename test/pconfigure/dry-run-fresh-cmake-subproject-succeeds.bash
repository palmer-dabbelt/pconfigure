#include "harness_start.bash"

# The cmake half of a dry run on a fresh tree: with a make generator
# the tree is built by "$(MAKE) -C obj/<tree>/build", which make runs
# under -n while only printing the cmake configure that would have
# created that directory.  The sub-make then stops on a missing
# directory, and "make -n" exits non-zero instead of describing the
# build.
#
# cmake here is a stand-in on the PATH, for the reason cmake.bash
# gives: what is under test is the Makefile pconfigure wrote, not
# cmake.

mkdir -p fake sub
cat >fake/cmake <<'EOF'
#!/bin/sh
build=
while [ "$#" -gt 0 ]
do
    case "$1" in
    -B) build="$2"; shift 2;;
    -B*) build="${1#-B}"; shift;;
    *) shift;;
    esac
done
if [ "$build" != "" ]
then
    mkdir -p "$build"
    printf 'all:\n\techo built > built\ninstall:\n\ttrue\n' > "$build/Makefile"
    touch "$build/CMakeCache.txt"
fi
EOF
chmod +x fake/cmake
export PATH="$tempdir/fake:$PATH"

cat >Configfile <<'EOF'
BUILD_SYSTEMS += cmake
SUBPROJECTS   += sub
EOF

cat >sub/CMakeLists.txt <<'EOF'
project(x NONE)
EOF

$PTEST_BINARY $PCONFIGURE_ARGS

make $MAKE_ARGS -n > dry.out 2>&1 || { cat dry.out; exit 1; }
cat dry.out
test ! -e obj/sub/build/Makefile

exit 0
