#include "harness_start.bash"

# A cmake subproject's "--jobs" becomes "cmake --build ... --parallel
# N", and is checked for being digits so that a bad one is refused
# where it was written.  "--jobs 0" is all digits too, but cmake
# refuses it ("The <jobs> value requires a positive integer
# argument."), so a check that stops at digits takes the line without
# a word and leaves the build to fail later, from inside a recipe.
# "00" is the same zero spelled longer.
mkdir -p sub
cat >sub/CMakeLists.txt <<'EOF2'
cmake_minimum_required(VERSION 3.10)
project(hello C)
EOF2

for zero in 0 00
do
    cat >Configfile <<EOF2
BUILD_SYSTEMS += cmake

SUBPROJECTS   += sub
CONFIGUREOPTS += --generator Ninja
CONFIGUREOPTS += --jobs $zero
EOF2

    rm -f Makefile
    if $PTEST_BINARY $PCONFIGURE_ARGS >jobs-$zero.out 2>&1
    then
        cat jobs-$zero.out
        exit 1
    fi
    cat jobs-$zero.out
    grep -q "Configfile:5" jobs-$zero.out
    grep -q "'--jobs $zero' isn't a number of jobs" jobs-$zero.out
    grep -q "'--jobs 8'" jobs-$zero.out
    test ! -e Makefile
done

# A number with a zero in it is still a number, and still taken.
cat >Configfile <<'EOF2'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += sub
CONFIGUREOPTS += --generator Ninja
CONFIGUREOPTS += --jobs 10
EOF2
$PTEST_BINARY $PCONFIGURE_ARGS
grep -q -- "--parallel 10" Makefile
