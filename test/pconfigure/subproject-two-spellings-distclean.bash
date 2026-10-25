#include "harness_start.bash"

# A subproject listed as both "sub" and "sub/" is one subproject, which
# subprojects-same-tree-two-spellings.bash checks from the Makefile's
# side.  This one checks the trailing-slash spelling from the other end
# of the build: the subproject's binary lands in sub/bin, not in some
# directory named after the slashed spelling, and distclean -- whose
# list of directories to remove is built from the same names -- takes
# sub/bin and sub/obj away again rather than missing them because one
# spelling had a slash on it.
mkdir -p src sub/src
echo 'int main(void) { return 0; }' > src/main.c
echo 'int main(void) { return 0; }' > sub/src/tool.c

cat >sub/Configfile <<EOF
LANGUAGES   += c
BINARIES    += tool
SOURCES     += tool.c
EOF

cat >Configfile <<EOF
SUBPROJECTS += sub
SUBPROJECTS += sub/

LANGUAGES   += c

BINARIES    += main
SOURCES     += main.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
./bin/main
./sub/bin/tool

make $MAKE_ARGS distclean
find . | sort
test ! -e bin
test ! -e sub/bin
test ! -e sub/obj
test -f sub/src/tool.c
