#include "harness_start.bash"

# A CONFIG in a subproject's Configfile names a file beside that
# Configfile -- sub/Configfile.extra -- rather than one at the top, and
# what it says builds in the subproject.  Under AUTORECONFIGURE the
# top's Makefile watches that file too, so editing it reconfigures.
mkdir -p sub/src

cat >Configfile <<'EOF'
AUTORECONFIGURE = true
SUBPROJECTS    += sub
EOF

cat >sub/Configfile <<'EOF'
CONFIG += extra
EOF

cat >sub/Configfile.extra <<'EOF'
LANGUAGES += c
BINARIES  += tool
SOURCES   += tool.c
EOF

echo 'int main(void) { return 0; }' > sub/src/tool.c

# A file of the same name at the top is a decoy: reading it, as the top
# would for its own CONFIG, stops pconfigure on a line it can't parse.
echo 'NOT_A_KEYWORD += x' > Configfile.extra
echo 'int main(void) { return 0; }' > sub/src/other.c

$PTEST_BINARY $PCONFIGURE_ARGS
grep -q "sub/Configfile.extra" Makefile
test ! -e bin/tool

make $MAKE_ARGS
test -x sub/bin/tool

# An edit to the subproject's CONFIG file is picked up by the next make
# from the top.
sleep 1
cat >>sub/Configfile.extra <<'EOF'
BINARIES  += other
SOURCES   += other.c
EOF
test ! -e sub/bin/other
make $MAKE_ARGS
test -x sub/bin/other

exit 0
