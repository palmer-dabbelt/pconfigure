#include "harness_start.bash"

# The "--deps" answer pconfigure records for a GENERATE rule is a
# snapshot taken while the Configfile was being read (taxonomy type
# 3).  The accepted consequence: a file the generator starts reading
# after that point is not on the rule, and edits to it alone
# regenerate nothing until the next configure.  This test is about the
# other half of that moment -- the generator picks up a new input
# file, the script itself is edited to read it, and the build has to
# hear about the new output the same way it hears about any other:
# a plain make, no manual reconfigure.
#
# The regeneration rides on the script's mtime, the one edge the
# script cannot help being on.  That a later edit to the new input
# alone stays invisible is the snapshot's edge, and it is stated in
# the comments here rather than asserted: the test's job is the
# propagation that does happen, not the one that deliberately does
# not.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h

BINARIES  += app
SOURCES   += app.c
EOF

echo 42 > src/input.txt

cat >src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     echo "src/input.txt" ;;
--generate) echo "#define ANSWER $(cat src/input.txt)" ;;
esac
EOF
chmod +x src/gen.h.proc

cat >src/app.c <<'EOF'
  #include "gen.h"
  #include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS > first.out 2>&1
cat first.out
test "$(./bin/app)" = "42"

# A build that has nothing to do is the ordinary answer from here on,
# which is what makes the build after the edit mean something.
make $MAKE_ARGS > settled.out 2>&1
cat settled.out
grep -q "Nothing to be done" settled.out

##############################################################################
# A late input appears, and the script starts reading it                     #
##############################################################################
sleep 2
echo 7 > src/late.txt
cat >src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     echo "src/input.txt" ;;
--generate) echo "#define ANSWER $(($(cat src/input.txt) + $(cat src/late.txt)))" ;;
esac
EOF
chmod +x src/gen.h.proc

# Plain make, no reconfigure: the rule for gen.h carries the script as
# its prerequisite, and the script's new body is what regenerates the
# output.
make $MAKE_ARGS > second.out 2>&1
cat second.out

if grep -q "^PCONFIGURE$" second.out
then
    exit 1
fi
grep -q "^GEN	gen.h$" second.out

# The consumer of the output recompiled and the binary relinked, and
# the answer the binary gives is the one the new input contributed.
grep -q "^CC	app.c$" second.out
grep -q "^LD	app$" second.out
test "$(./bin/app)" = "49"

exit 0
