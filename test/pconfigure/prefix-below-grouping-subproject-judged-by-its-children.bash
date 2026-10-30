#include "harness_start.bash"

# A subproject that only pulls in others -- a directory of vendored
# trees, say -- installs nothing of its own, so its own prefix says
# nothing about where anything goes.  A late PREFIX in the parent is
# judged by the libraries under it, at whatever depth: here the one
# library sets /opt/top itself, so the parent setting /opt/top after
# reading the group is one consistent install and is left alone.
mkdir -p src a/b/src

cat >Configfile <<'EOF'
SUBPROJECTS += a
PREFIX       = /opt/top
LANGUAGES   += c
BINARIES    += main
LINKOPTS    += -La/b/lib
LINKOPTS    += -lb
SOURCES     += main.c
EOF

cat >a/Configfile <<'EOF'
SUBPROJECTS += b
EOF

cat >a/b/Configfile <<'EOF'
PREFIX     = /opt/top
LANGUAGES += c
LIBRARIES += libb.so
SOURCES   += b.c
EOF

echo 'int b(void) { return 3; }' > a/b/src/b.c
echo 'int b(void); int main(void) { return b() - 3; }' > src/main.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS install DESTDIR=$(pwd)/stage
find stage -type f

test -f stage/opt/top/bin/main
test -f stage/opt/top/lib/libb.so
test ! -e stage/usr/local/lib/libb.so

# Without that line the library is on the /usr/local the group was
# handed and passed down, and the parent's PREFIX splits from it.  The
# error names the subproject this Configfile read and the line, two
# levels down, that asked for the library.
sed -i.bak '/^PREFIX/d' a/b/Configfile
if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
then
    cat configure.out
    exit 1
fi
cat configure.out

grep -q "^\./Configfile:2 'PREFIX = /opt/top'" configure.out
grep -q "the subproject 'a' was already read, and its library 'libb.so' installs into '/usr/local'" configure.out
grep -q "that library was asked for at a/b/Configfile:2 'LIBRARIES += libb.so'" configure.out
