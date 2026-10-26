#include "harness_start.bash"

# An install prefix outside the object directory is a fatal error, but
# it can only be checked once the tree is bound, long after the line
# that wrote it has been read.  The refusal still has to name that
# line, which it finds through the record kept when the option was
# read.  Two trees are vendored here, so the option text alone can't
# say which line wrote it.
mkdir -p one two
echo 'project(one NONE)' > one/CMakeLists.txt
echo 'project(two NONE)' > two/CMakeLists.txt

cat >Configfile <<'EOF2'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += one
CONFIGUREOPTS += --prefix obj/toolchain

SUBPROJECTS   += two
CONFIGUREOPTS += --prefix /usr/local
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    exit 1
fi
cat out
grep -q "'--prefix /usr/local' is an absolute path" out
grep -q "Configfile:7" out

exit 0
