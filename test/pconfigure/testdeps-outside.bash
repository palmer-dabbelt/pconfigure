#include "harness_start.bash"

mkdir -p src test/integration fs/src vm/src escape/sub/src escape/sub/test/app

##############################################################################
# The way it's supposed to be written                                        #
##############################################################################
# A test that's about two projects at once is an integration test, and
# it belongs to the project that has both of them.  From up here the
# path to either one is an ordinary path that never leaves the tree,
# which is the whole point: this Makefile knows how to build both ends
# of every dependency it names.
cat >Configfile <<EOF
SUBPROJECTS += fs
SUBPROJECTS += vm

LANGUAGES   += c
LANGUAGES   += bash

BINARIES    += integration
TESTDEPS    += fs/libexec/mkfs
TESTDEPS    += vm/bin/vm
SOURCES     += integration.c
TESTSRC     += boots.bash
EOF

cat >fs/Configfile <<EOF
LANGUAGES += c

LIBEXECS  += mkfs
SOURCES   += mkfs.c
EOF

cat >vm/Configfile <<EOF
LANGUAGES += c

BINARIES  += vm
SOURCES   += vm.c
EOF

cat >src/integration.c <<EOF
int main(void) { return 0; }
EOF

cat >fs/src/mkfs.c <<EOF
  #include <stdio.h>
int main(void) { printf("mkfs\n"); return 0; }
EOF

cat >vm/src/vm.c <<EOF
  #include <stdio.h>
int main(void) { printf("vm\n"); return 0; }
EOF

# The test finds both of them the way a test finds anything: relative
# to the binary it was attached to, which it is handed as an absolute
# path.  Its own working directory is wherever make was run and is not
# something it gets to assume.
cat >test/integration/boots.bash <<'EOF'
here="$(dirname "$(dirname "$PTEST_BINARY")")"
test "$("$here"/fs/libexec/mkfs)" = "mkfs"
test "$("$here"/vm/bin/vm)" = "vm"
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# Both prerequisites are ordinary paths in the Makefile of the project
# that named them, and that project knows how to build both, because
# it includes the Makefiles that do.
grep -q "^check/integration/boots.bash:.* fs/libexec/mkfs" Makefile
grep -q "^check/integration/boots.bash:.* vm/bin/vm" Makefile

# Nothing was built before "make check", so the only reason either
# program exists afterwards is that the test asked for it.
make $MAKE_ARGS check
test -x fs/libexec/mkfs
test -x vm/bin/vm
test "$(tar -xOf check/integration/boots.bash ptest__return)" = "0"

##############################################################################
# Climbing out of the project                                                #
##############################################################################
# The thing that isn't allowed, and the reason it isn't: a subproject
# that names "../sibling/..." is writing down a path whose meaning
# depends on who is standing where.  From the top it points at a
# sibling; from inside the subproject, which is a place somebody can
# stand and run make, it points out of the world.  A dependency that
# means two different things isn't one, so it's refused where it's
# written rather than resolved differently depending on how the build
# was started.
cat >escape/Configfile <<EOF
SUBPROJECTS += sub
EOF

cat >escape/sub/Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash

BINARIES  += app
TESTDEPS  += ../../nowhere/tool
SOURCES   += app.c
TESTSRC   += t.bash
EOF

cat >escape/sub/src/app.c <<EOF
int main(void) { return 0; }
EOF

cat >escape/sub/test/app/t.bash <<'EOF'
true
EOF

# The subshell is the assertion: "set -e" is on, so a command expected
# to fail has to be somewhere a failure isn't fatal.
if (cd escape && $PTEST_BINARY $PCONFIGURE_ARGS) > escape.out 2>&1
then
    exit 1
fi
cat escape.out
grep -q "TESTDEPS can't reach outside the project" escape.out

# ... and the message says what to do instead, because "no" on its own
# is not much help to somebody who has a real dependency to express.
grep -q "link line" escape.out
grep -q "whoever has both of them" escape.out

# It stopped before writing anything, rather than leaving a
# half-configured tree behind for the next command to trip over.
test ! -e escape/Makefile
test ! -e escape/sub/Makefile

# The same answer standing inside the subproject.  This is the half
# that a check written against the project's own directory would get
# wrong: based against "escape/sub/" the path resolves to something
# perfectly ordinary, and it's only by asking about the path on its
# own that both places agree.
if (cd escape/sub && $PTEST_BINARY $PCONFIGURE_ARGS) > standalone.out 2>&1
then
    exit 1
fi
cat standalone.out
grep -q "TESTDEPS can't reach outside the project" standalone.out
test ! -e escape/sub/Makefile

##############################################################################
# Starting from the root                                                     #
##############################################################################
# An absolute path is out of the tree too, and for the same reason: it
# names a file this build has no idea how to make, so a Makefile that
# depended on it would either be a no-op or an error depending on what
# happened to be installed.
rm -rf abs
mkdir -p abs/src abs/test/app

cat >abs/Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash

BINARIES  += app
TESTDEPS  += /usr/bin/true
SOURCES   += app.c
TESTSRC   += t.bash
EOF

cat >abs/src/app.c <<EOF
int main(void) { return 0; }
EOF

cat >abs/test/app/t.bash <<'EOF'
true
EOF

if (cd abs && $PTEST_BINARY $PCONFIGURE_ARGS) > abs.out 2>&1
then
    exit 1
fi
cat abs.out
grep -q "TESTDEPS can't reach outside the project" abs.out
test ! -e abs/Makefile

exit 0
