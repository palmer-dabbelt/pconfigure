#include "harness_start.bash"

# A GENERATE rule's inputs are whatever its script printed for
# "--deps" when pconfigure last ran, written into the rule's
# prerequisites beside the script itself.  That edge is the first half
# of the generated-header chain -- input, header, object -- and it is
# the half nothing else in the suite moves: every other dependency in
# a pconfigure tree is a file a Configfile named, and this one is a
# file a script said it read.
#
# Which is CMake's add_custom_command(OUTPUT ... DEPENDS ...) shape
# (taxonomy type 3).  The second half of the chain, the object hearing
# about the header, is pdeps' job and is pinned elsewhere; the
# assertions below go red from a missing edge in either place, which
# is why the log is read as well as the binary.
#
# Two sources, so that a consumer of the generated header can be told
# apart from a bystander: "other.c" reads nothing generated, and a
# build that recompiles it alongside "app.c" is a build that
# propagates further than the dependency graph says it should.
#
# The GENERATE line stands before the sources that read the header:
# the include pconfigure resolves for app.c is resolved against files
# that exist while the Configfile is being read, and a generated
# header whose rule has not been processed yet is not one of them.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h

BINARIES  += app
SOURCES   += app.c
SOURCES   += other.c
EOF

cat >src/input.txt <<EOF
42
EOF

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

cat >src/other.c <<'EOF'
int other(void) { return 9; }
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
# The input changes                                                          #
##############################################################################
sleep 2
echo 43 > src/input.txt

make $MAKE_ARGS > second.out 2>&1
cat second.out

# The output was regenerated from the new input ...
grep -q "^GEN	gen.h$" second.out

# ... the consumer of it recompiled, and the binary relinked ...
grep -q "^CC	app.c$" second.out
grep -q "^LD	app$" second.out

# ... the bystander did not ...
if grep -q "^CC	other.c$" second.out
then
    exit 1
fi

# ... and the answer the binary gives is the new one, which is the
# part a stale object would get wrong.
test "$(./bin/app)" = "43"

exit 0
