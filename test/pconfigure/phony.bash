#include "harness_start.bash"

mkdir -p fs/src vm/src test/integration sub/src sub/test/thing

# The shape this exists for: a project whose whole reason for having a
# top level is the tests that drive several subprojects at once.  There
# is no program up here to hang them off.
cat >Configfile <<EOF
SUBPROJECTS += fs
SUBPROJECTS += vm

LANGUAGES   += bash

PHONY       += integration
TESTDEPS    += fs/libexec/mkfs
TESTDEPS    += vm/bin/vm
TESTSRC     += boots.bash

SUBPROJECTS += sub
EOF

cat >fs/Configfile <<EOF
LANGUAGES += bash

LIBEXECS  += mkfs
SOURCES   += mkfs.bash
EOF

cat >vm/Configfile <<EOF
LANGUAGES += bash

BINARIES  += vm
SOURCES   += vm.bash
EOF

# A phony in a subproject, to check the name is rooted at whoever
# asked for it rather than landing in everybody's Makefile at once.
cat >sub/Configfile <<EOF
LANGUAGES += bash

PHONY     += thing
TESTSRC   += runs.bash
EOF

cat >fs/src/mkfs.bash <<EOF
echo mkfs-ran
EOF

cat >vm/src/vm.bash <<EOF
echo vm-ran
EOF

cat >test/integration/boots.bash <<EOF
set -e

# Both subprojects were built before this ran, which is what the
# TESTDEPS asked for.
test "\$(./fs/libexec/mkfs)" = "mkfs-ran"
test "\$(./vm/bin/vm)" = "vm-ran"

# There is no program being tested, and pconfigure says so rather than
# handing over a path to something that isn't one.
test "\$PTEST_BINARY" = ""

exit 0
EOF

cat >sub/test/thing/runs.bash <<EOF
exit 0
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
cat sub/Makefile

# The target is a name, and make is told so.  Without that, a file
# called "integration" turning up in the tree would stop it working.
grep -q "^\.PHONY: integration$" Makefile
grep -q "^integration: fs/libexec/mkfs vm/bin/vm$" Makefile

# It builds nothing itself, so it stays out of "all": everything it
# names is built by whoever builds it anyway.
if grep -q "^all: integration$" Makefile
then
    exit 1
fi

# The test hanging off it gets no binary, because there isn't one.
grep -q "ptest --test obj/check/integration/boots.bash --out check/integration/boots.bash\$" Makefile

# A phony belongs to the project that asked for it, the same way every
# other target does -- so two projects can both want one called the
# same thing, and asking for it from the top or from inside the
# project reaches the same one.
grep -q "^\.PHONY: \$(pconfigure_subdir_sub)thing$" sub/Makefile
if grep -q "^\.PHONY: thing$" Makefile
then
    exit 1
fi

# Asking for it by name builds what it stands for.
make $MAKE_ARGS integration
test -x fs/libexec/mkfs
test -x vm/bin/vm

make $MAKE_ARGS
make $MAKE_ARGS check
ptest --verbose

# Both tests ran and passed: the one under the top-level phony and the
# one under the subproject's.
test -f check/integration/boots.bash
test -f sub/check/thing/runs.bash

# A TESTS with nothing open above it is still an error, and the advice
# now has an answer for the case that used to have none.
mkdir -p bad
cat >bad/Configfile <<EOF
LANGUAGES += bash

TESTSRC   += orphan.bash
EOF

if (cd bad && $PTEST_BINARY $PCONFIGURE_ARGS) > bad.out 2>&1
then
    exit 1
fi
cat bad.out
grep -q "with no target open above it has nothing to test" bad.out
grep -q "PHONY" bad.out

exit 0
