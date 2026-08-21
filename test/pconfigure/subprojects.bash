#include "harness_start.bash"

mkdir -p src test/test sub/src sub/test/helper

# Note that there's no "DEPLIBS += sub" here, and nothing in the
# subproject's Configfile that knows it's a subproject at all.
cat >Configfile <<EOF
SUBPROJECTS += sub

LANGUAGES   += c
LANGUAGES   += bash

BINARIES    += test
COMPILEOPTS += -Isub/include
LINKOPTS    += -Lsub/lib
LINKOPTS    += -lsub
SOURCES     += test.c
TESTSRC     += top.bash
EOF

cat >sub/Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash
LANGUAGES += h

HEADERSRC += sub.h

LIBRARIES += libsub.so
SOURCES   += sub.c

LIBEXECS  += helper
SOURCES   += helper.c
TESTSRC   += works.bash
EOF

cat >sub/src/sub.h <<EOF
int sub(void);
EOF

cat >sub/src/sub.c <<EOF
int sub(void) { return 7; }
EOF

cat >sub/src/helper.c <<EOF
int main(void) { return 0; }
EOF

cat >src/test.c <<EOF
  #include <sub.h>
  #include <stdio.h>
int main(void) { printf("%d\n", sub()); return 0; }
EOF

cat >test/test/top.bash <<'EOF'
test "$($PTEST_BINARY)" = "7"
EOF

cat >sub/test/helper/works.bash <<'EOF'
$PTEST_BINARY
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
cat sub/Makefile

# The subproject gets a Makefile of its own, which the top-level one
# includes rather than recursing into.
test -f sub/Makefile
grep -q "^pconfigure_subdir_sub ?= sub/$" Makefile
grep -q "^include \$(pconfigure_subdir_sub)Makefile$" Makefile
if grep -q "make -C" Makefile
then
    exit 1
fi

# The subproject's own Makefile defaults its prefix to nothing, which
# is what makes it work when make is run in the subproject instead.
grep -q "^pconfigure_subdir_sub ?=$" sub/Makefile
grep -q "^\$(pconfigure_subdir_sub)lib/libsub.so:" sub/Makefile

make $MAKE_ARGS
test "$(./bin/test)" = "7"

# Nothing said DEPLIBS: the dependency on the subproject's library was
# worked out from the "-lsub" on the link line.
grep -q "^obj/bin/test/.*/local: sub/lib/libsub.so$" Makefile

# The tests of both projects run, and are told apart by which project
# they came from.
make $MAKE_ARGS check
test -f check/test/top.bash
test -f sub/check/helper/works.bash
test "$(tar -xOf check/test/top.bash ptest__return)" = "0"
test "$(tar -xOf sub/check/helper/works.bash ptest__return)" = "0"
make $MAKE_ARGS report
grep -q "	test/top.bash$" obj/check-report
grep -q "	sub/helper/works.bash$" obj/check-report

# Everything installs into one prefix, the subproject included -- it
# does not end up under a "sub" of its own.
make $MAKE_ARGS D=$(pwd)/install DESTDIR=$(pwd)/install install
test -f install/usr/local/bin/test
test -f install/usr/local/lib/libsub.so
test -f install/usr/local/include/sub.h
test ! -e install/usr/local/sub

# The subproject still builds standalone, using the same Makefile.
cd sub
rm -rf lib include obj check
make $MAKE_ARGS
test -f lib/libsub.so
test -f include/sub.h
./libexec/helper
make $MAKE_ARGS check
test -f check/helper/works.bash
cd ..

# ... and having built it that way doesn't stop the top level from
# building.
make $MAKE_ARGS
test "$(./bin/test)" = "7"

exit 0
