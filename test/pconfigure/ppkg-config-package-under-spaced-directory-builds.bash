#include "harness_start.bash"

# A package installed under a directory with a space in its name, the
# way things end up under "My Documents" or "/opt/vendor tools".
# pkg-config spells the space as "\ " in its answer, which is what the
# shell running the compile recipe wants, and the compile itself is
# fine with it.  pconfigure's header scan understands the escape too:
# it follows the -I and finds the package's header.  But it then writes
# that header's path into the Makefile as a prerequisite with the space
# bare, so make reads the path as two files, has no rule for the first
# half, and stops before compiling anything.
mkdir -p proj/src "pkgs/my dir/include" pc

cat >"pkgs/my dir/include/spaced.h" <<'EOF'
#define SPACED 5
EOF

cat >pc/spaced.pc <<EOF
prefix=$(pwd)/pkgs/my\\ dir
includedir=\${prefix}/include

Name: spaced
Description: a package under a spaced directory
Version: 1.0
Cflags: -I\${includedir}
EOF

export PKG_CONFIG_PATH="$(pwd)/pc"
pkg-config spaced --cflags

cd proj

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += test
COMPILEOPTS += `ppkg-config spaced --cflags`
SOURCES     += test.c
EOF

cat >src/test.c <<'EOF'
#include <spaced.h>
int main(void) { return SPACED; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

set +e
./bin/test
status="$?"
set -e
test "$status" = "5"

exit 0
