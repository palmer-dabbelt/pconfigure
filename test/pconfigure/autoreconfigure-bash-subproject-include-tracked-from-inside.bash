#include "harness_start.bash"
#pconfigure TESTDEPS += bin/pdeps

# A subproject's Makefile is read from two places: included by its
# parent at the top of the tree, and run where it sits.  What pdeps
# writes about a script is one file both of those read, so it has to
# be spelled from the top whichever of them asked -- a fragment
# written from inside that named "inc/lib.bash" would be a file the
# build from the top had never heard of.  The include's directory is
# the subproject's own, through a "-I", so the path has to be right
# from both places for the edit to be followed at all.
export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p sub/src sub/inc

cat >Configfile <<EOF
AUTORECONFIGURE = true

SUBPROJECTS += sub
EOF

cat >sub/Configfile <<EOF
LANGUAGES   += bash

BINARIES    += tool
COMPILEOPTS += -Iinc
SOURCES     += tool.bash
EOF

cat >sub/src/tool.bash <<'EOF'
#!/bin/bash
echo plain
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./sub/bin/tool)" = "plain"

# The include arrives, and is followed from the top.
sleep 2
cat >sub/inc/lib.bash <<'EOF'
echo one
EOF
cat >sub/src/tool.bash <<'EOF'
#!/bin/bash
#include "lib.bash"
EOF
make $MAKE_ARGS
test "$(./sub/bin/tool)" = "one"

# Then edited and built from inside the subproject.
sleep 2
cat >sub/inc/lib.bash <<'EOF'
echo two
EOF
(cd sub && make $MAKE_ARGS -f obj/Makefile.sub)
test "$(./sub/bin/tool)" = "two"

# And the top still reads what the inside wrote: one more edit is
# followed, and then there is nothing left to do.
sleep 2
cat >sub/inc/lib.bash <<'EOF'
echo three
EOF
make $MAKE_ARGS
test "$(./sub/bin/tool)" = "three"

make $MAKE_ARGS > settled.out 2>&1
cat settled.out
grep -q "Nothing to be done" settled.out

exit 0
