#include "harness_start.bash"

# A cmake '--define' is checked for an '=', but '--define =ON' has
# nothing in front of it and becomes "cmake -D=ON", which cmake refuses
# ("Parse error in command line argument") when the tree is first
# configured, from inside a recipe.  cmake ends a -D's name at a ':' as
# well, for the type, so ':BOOL=ON' has no name either.  Both are
# refused at the Configfile line, and a name with a type is still
# taken.
mkdir -p sub
cat >sub/CMakeLists.txt <<'EOF2'
cmake_minimum_required(VERSION 3.10)
project(hello C)
EOF2

for define in '=ON' ':BOOL=ON'
do
    cat >Configfile <<EOF2
BUILD_SYSTEMS += cmake
SUBPROJECTS   += sub
CONFIGUREOPTS += --define $define
EOF2

    if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
    then
        cat out
        echo "'--define $define' was accepted"
        exit 1
    fi
    cat out
    grep -q "Configfile:3" out
    grep -qF "'--define $define' has no name in front of its '='" out
    test ! -e Makefile
done

cat >Configfile <<'EOF2'
BUILD_SYSTEMS += cmake
SUBPROJECTS   += sub
CONFIGUREOPTS += --define BUILD_TESTING:BOOL=OFF
EOF2
$PTEST_BINARY $PCONFIGURE_ARGS

exit 0
