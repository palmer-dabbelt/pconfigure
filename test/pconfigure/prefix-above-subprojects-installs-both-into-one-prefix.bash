#include "harness_start.bash"

# A PREFIX written above the SUBPROJECTS line is the one the subproject
# is read under, so the library it builds and the binary that links it
# install into one prefix, and the installed binary's run-time search
# path is that prefix's library directory rather than the default
# prefix's or the build tree's.
mkdir -p src sub/src

cat >Configfile <<'EOF2'
PREFIX       = /opt/top

SUBPROJECTS += sub

LANGUAGES   += c
BINARIES    += main
LINKOPTS    += -Lsub/lib
LINKOPTS    += -lsub
SOURCES     += main.c
EOF2

cat >sub/Configfile <<'EOF2'
LANGUAGES += c
LIBRARIES += libsub.so
SOURCES   += sub.c
EOF2

echo 'int sub(void) { return 3; }' > sub/src/sub.c
echo 'int sub(void); int main(void) { return sub() - 3; }' > src/main.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS install DESTDIR=$(pwd)/stage
find stage -type f

test -x stage/opt/top/bin/main
test -f stage/opt/top/lib/libsub.so
test ! -e stage/usr

readelf -d stage/opt/top/bin/main > dyn.out
cat dyn.out
grep -q 'R.*PATH.*/opt/top/lib' dyn.out
if grep -q 'ORIGIN\|/usr/local' dyn.out
then
    exit 1
fi

exit 0
