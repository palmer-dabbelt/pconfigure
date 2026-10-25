#include "harness_start.bash"

# A late PREFIX is refused because the subprojects already read would
# install somewhere else -- which is a question about where they do
# install, not about the prefix they were handed.  A subproject whose
# own Configfile says "PREFIX = /opt/top" installs into /opt/top
# whatever its parent's prefix was when it was read, so a parent that
# sets the same prefix after it is building one consistent tree and is
# left alone.
mkdir -p src sub/src

cat >Configfile <<'EOF'
SUBPROJECTS += sub

PREFIX       = /opt/top

LANGUAGES   += c
BINARIES    += main
LINKOPTS    += -Lsub/lib
LINKOPTS    += -lsub
SOURCES     += main.c
EOF

cat >sub/Configfile <<'EOF'
PREFIX     = /opt/top
LANGUAGES += c
LIBRARIES += libsub.so
SOURCES   += sub.c
EOF

echo 'int sub(void) { return 3; }' > sub/src/sub.c
echo 'int sub(void); int main(void) { return sub() - 3; }' > src/main.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS install DESTDIR=$(pwd)/stage
find stage -type f

test -f stage/opt/top/bin/main
test -f stage/opt/top/lib/libsub.so
test ! -e stage/usr/local/lib/libsub.so

# A subproject that gives its library some third prefix installs it
# there wherever the parent's PREFIX is written: moving the line above
# the SUBPROJECTS wouldn't change where the library goes, so the line
# isn't what split the install and isn't refused for it.  The library
# goes where its own Configfile said.
sed -i 's@^PREFIX .*@PREFIX     = /opt/sub@' sub/Configfile
rm -rf stage
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS install DESTDIR=$(pwd)/stage
find stage -type f

test -f stage/opt/top/bin/main
test -f stage/opt/sub/lib/libsub.so
