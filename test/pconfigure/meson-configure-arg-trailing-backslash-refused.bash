#include "harness_start.bash"

# A meson '--configure-arg' is pasted raw in front of the build and
# source directories.  One that ends in a backslash escapes the space
# after it, so the build directory is glued onto the argument and
# meson is handed one positional argument rather than two.  Nothing
# fails loudly, and the setup that runs is not the one written, so a
# trailing backslash has to be refused at the line.
mkdir -p sub
touch sub/meson.build

cat >Configfile <<'EOF2'
BUILD_SYSTEMS += meson
SUBPROJECTS   += sub
CONFIGUREOPTS += --configure-arg -Dname=x\
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    cat out
    grep -n "Dname" Makefile || true
    exit 1
fi
cat out
grep -q "Configfile:3" out
grep -q "ends in a backslash" out

exit 0
