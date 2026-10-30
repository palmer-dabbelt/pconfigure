#include "harness_start.bash"

# The installed flavour of a link bakes PREFIX in, as the rpath that
# says where its libraries will be once installed.  Changing PREFIX
# has to relink it, or "make install" puts a program under the new
# prefix that goes looking for its libraries under the old one.  The
# link's directory is named after a hash of the link options, which
# is what makes a LINKOPTS change relink, so PREFIX has to be in that
# hash too even though it never appears in a LINKOPTS.
#
# AUTORECONFIGURE is on so the edit reaches the Makefile the way it
# would in a real tree, through the reconfigure rule.

export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src

cat >src/main.c <<'EOF'
int main(void) { return 0; }
EOF

cat >Configfile <<EOF
AUTORECONFIGURE = true
PREFIX          = /opt/one

LANGUAGES += c

BINARIES  += app
SOURCES   += main.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
make $MAKE_ARGS DESTDIR=$(pwd)/first install
if test "$(uname -s)" == "Darwin"; then otool -l first/opt/one/bin/app | grep -q '/opt/one/lib'; else readelf -d first/opt/one/bin/app | grep -q "R.*PATH.*/opt/one/lib"; fi

sleep 2
sed -i.bak 's@/opt/one@/opt/two@' Configfile

make $MAKE_ARGS
make $MAKE_ARGS DESTDIR=$(pwd)/second install
if test "$(uname -s)" == "Darwin"; then otool -l second/opt/two/bin/app > second.dyn; else readelf -d second/opt/two/bin/app > second.dyn; fi
cat second.dyn
if test "$(uname -s)" == "Darwin"; then grep -q '/opt/two/lib' second.dyn; else grep -q "R.*PATH.*/opt/two/lib" second.dyn; fi
if grep -q "/opt/one" second.dyn
then
    exit 1
fi
