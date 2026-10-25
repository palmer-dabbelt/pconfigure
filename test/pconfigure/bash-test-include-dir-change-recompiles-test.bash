#include "harness_start.bash"

# A BASH TESTSRC is compiled by pbashc with the options of the target
# it sits under, into obj/check/, and its result is rebuilt when that
# compiled copy is.  Moving the target's "-I" changes which file the
# test pastes in, but the compiled test is newer than either candidate
# and nothing in its rule used to change with the options, so "make
# check" reran nothing and reported what the test said against the old
# file.
mkdir -p src test/tool pass fail

cat >src/tool.bash <<'EOF'
#!/bin/bash
echo tool
EOF

cat >test/tool/t.bash <<'EOF'
#include "verdict.bash"
EOF

cat >fail/verdict.bash <<'EOF'
exit 1
EOF

cat >pass/verdict.bash <<'EOF'
exit 0
EOF

cat >Configfile <<EOF
LANGUAGES   += bash

BINARIES    += tool
COMPILEOPTS += -Ifail
SOURCES     += tool.bash
TESTSRC     += t.bash
EOF

sleep 2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS check || true
test "$(tar -xOf check/tool/t.bash ptest__return)" != "0"

sleep 2
sed -i 's/-Ifail/-Ipass/' Configfile

$PTEST_BINARY $PCONFIGURE_ARGS
grep -q "pbashc' -i test/tool/t.bash .*-Ipass" Makefile

make $MAKE_ARGS check
test "$(tar -xOf check/tool/t.bash ptest__return)" = "0"

exit 0
