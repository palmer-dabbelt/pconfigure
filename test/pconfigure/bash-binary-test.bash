#include "harness_start.bash"

mkdir -p src test/test

# A test is a child of the thing it tests, and the project only ever
# hands a language its own output contexts -- so a language that never
# walks down to its TEST children emits no check target for them.  A
# TESTSRC under a binary of such a language then builds nothing, runs
# nothing and says nothing about it, which is the worst way for a test
# to not exist: the Configfile names it and "make check" agrees that
# everything passed.
#
# BASH was such a language.  It went unnoticed because the tests of a C
# or C++ binary are reached by languages/cxx.c++ walking its children,
# and everything in this tree is built by pconfigure, which is C++.
# pclean is the only BASH binary with a test to its name.

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES += test
SOURCES += test.bash
TESTSRC += runs.bash
EOF

cat >src/test.bash <<'EOF'
echo "Success"
EOF

cat >test/test/runs.bash <<'EOF'
exit 0
EOF

cat >test.gold <<'EOF'
Success
EOF

#include "harness_end.bash"

# harness_end ran "make check" for us.  The whole point is that it had
# something to run, so look for the result rather than trusting that a
# suite of nothing came back clean.
test -f check/test/runs.bash
test "$(tar -xOf check/test/runs.bash ptest__return)" = "0"

exit 0
