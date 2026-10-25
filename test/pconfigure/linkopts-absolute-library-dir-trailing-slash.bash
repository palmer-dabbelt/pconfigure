#include "harness_start.bash"

# The same "-L" as in the relative case, but spelled as an absolute
# path the way a "$(pwd)" or a pkg-config answer would spell it.  The
# part that names this tree is taken off before the directory is
# matched against where the library is built, and the trailing slash
# that's left over after that has to go too, or "make bin/main" links
# before anything has built the library it needs.
mkdir -p src sub/src

cat >Configfile <<EOF
SUBPROJECTS += sub

LANGUAGES   += c
BINARIES    += main
LINKOPTS    += -L$(pwd)/sub/libs/
LINKOPTS    += -lsub
SOURCES     += main.c
EOF

cat >sub/Configfile <<'EOF'
LANGUAGES += c
LIBDIR     = libs
LIBRARIES += libsub.so
SOURCES   += sub.c
EOF

echo 'int sub(void) { return 3; }' > sub/src/sub.c
echo 'int sub(void); int main(void) { return sub() - 3; }' > src/main.c

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

grep -q "^obj/bin/main/.*/local: sub/libs/libsub.so$" Makefile

make $MAKE_ARGS -j2 bin/main
./bin/main
