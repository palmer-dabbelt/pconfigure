#include "harness_start.bash"

cat >Configfile <<EOF
LANGUAGES   += c
LANGUAGES   += bash

BINARIES    += test
SOURCES     += test.c

LIBEXECS    += helper-installed
SOURCES     += installed.c

TESTEXECS   += helper-testonly
SOURCES     += testonly.c
TESTSRC     += runs-testexec.bash

TESTEXECS   += script-testonly
SOURCES     += testonly.bash
EOF

mkdir -p src test/helper-testonly

cat >src/test.c <<EOF
int main() { return 0; }
EOF

cat >src/installed.c <<EOF
  #include <stdio.h>
int main() { printf("installed\n"); return 0; }
EOF

cat >src/testonly.c <<EOF
  #include <stdio.h>
int main() { printf("testonly\n"); return 0; }
EOF

cat >src/testonly.bash <<'EOF'
echo "testonly"
EOF

cat >test/helper-testonly/runs-testexec.bash <<'EOF'
test "$($PTEST_BINARY)" = "testonly"
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS

# A TESTEXEC is built by "make", just like everything else.
test -x testexec/helper-testonly
test -x testexec/script-testonly
test -x libexec/helper-installed
test -x bin/test

# ... and it's a first-class binary as far as the tests are concerned, with
# $PTEST_BINARY pointing at it.
make $MAKE_ARGS check
test "$(tar -xOf check/helper-testonly/runs-testexec.bash ptest__return)" = "0"

# ... but unlike a LIBEXEC it never gets installed.
make $MAKE_ARGS D=$(pwd)/install DESTDIR=$(pwd)/install install
test -f install/usr/local/bin/test
test -f install/usr/local/libexec/helper-installed
test ! -e install/usr/local/testexec/helper-testonly
test ! -e install/usr/local/testexec/script-testonly
test ! -d install/usr/local/testexec

# ... so "make uninstall" has nothing to say about it, either.
make $MAKE_ARGS D=$(pwd)/install DESTDIR=$(pwd)/install uninstall
test ! -e install/usr/local/bin/test
test ! -e install/usr/local/libexec/helper-installed

# "make distclean" knows where TESTEXECs live, as it does for the other
# output directories.
make $MAKE_ARGS distclean
test ! -d testexec
