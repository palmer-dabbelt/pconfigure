#include "harness_start.bash"

# Installing and uninstalling a nested BASH BINARIES and LIBEXECS is
# already pinned by uninstall-removes-installed-scripts.bash and
# libexecs-install-and-uninstall.bash.  What this adds is the rest of
# the nested-name story for scripts: the test for a nested BINARIES is
# looked up under the same nested name in test/, a LIBEXECS whose last
# component has a dot in it keeps that dot rather than having it taken
# for an extension, and the script's #include reaches into a
# subdirectory of the source tree.
mkdir -p src/sub test/tools/run

cat >src/run.bash <<'EOF'
#!/bin/bash
#include "sub/lib.bash"
hello
EOF
echo 'hello() { echo hi; }' > src/sub/lib.bash
echo 'test "$($PTEST_BINARY)" = hi' > test/tools/run/t.bash

cat >Configfile <<EOF
LANGUAGES += bash

BINARIES  += tools/run
SOURCES   += run.bash
TESTSRC   += t.bash

LIBEXECS  += helpers/run.v2
SOURCES   += run.bash
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/tools/run)" = hi
test "$(./libexec/helpers/run.v2)" = hi
test ! -e libexec/helpers/run

make $MAKE_ARGS check
test "$(tar -xOf check/tools/run/t.bash ptest__return)" = 0

make $MAKE_ARGS DESTDIR=$tempdir/dest install
test "$(dest/usr/local/libexec/helpers/run.v2)" = hi
