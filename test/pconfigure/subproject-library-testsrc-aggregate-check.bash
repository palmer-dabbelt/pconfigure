#include "harness_start.bash"

# The same library test, inside a subproject, run by "make check" at
# the top.  A subproject is very often a library -- that is usually
# why it was pulled in -- so a test attached to one is the common case
# for the aggregate check, and the rule it gets has to wait on what
# the subproject actually builds.
mkdir -p src dep/src dep/test/libdep.so

cat >Configfile <<EOF
SUBPROJECTS += dep

LANGUAGES   += c
BINARIES    += top
LINKOPTS    += -Ldep/lib
LINKOPTS    += -ldep
SOURCES     += top.c
EOF

cat >dep/Configfile <<EOF
LANGUAGES   += c
LANGUAGES   += bash

LIBRARIES   += libdep.so
SOURCES     += dep.c
TESTSRC     += loads.bash
EOF

echo 'int dep(void) { return 0; }' > dep/src/dep.c
echo 'int dep(void); int main(void) { return dep(); }' > src/top.c

cat >dep/test/libdep.so/loads.bash <<'EOF'
test -f "$PTEST_BINARY"
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
./bin/top

make $MAKE_ARGS check
test "$(tar -xOf dep/check/libdep.so/loads.bash ptest__return)" = "0"

exit 0
