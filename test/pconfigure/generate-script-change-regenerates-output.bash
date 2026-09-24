#include "harness_start.bash"

# The script of a GENERATE rule is the first prerequisite of the rule
# pconfigure writes for its output, which puts it in the same class as
# any other input: newer script, regenerated output.  CMake spells the
# same thing DEPENDS on the custom command that also carries the
# COMMAND (taxonomy type 3); the difference is that here the script is
# a file in the project rather than a line of the build definition,
# and so the edit that fires the regeneration is an ordinary edit to
# an ordinary file, made after the configure, heard about by a plain
# make.
#
# What this pins that the input-file test does not: the regeneration
# riding on the script's own mtime rather than on the mtime of
# anything the script reads.  The configure-time "--deps" answer is
# still what puts the file on the rule -- the script names the input
# it read when pconfigure ran, and that snapshot is the accepted
# semantics (see generate-late-input-appears.bash for the edge of it).

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
# The script changes                                                         #
##############################################################################
sleep 2
cat >src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     echo "src/input.txt" ;;
--generate) echo "#define ANSWER $(($(cat src/input.txt) + 100))" ;;
esac
EOF
chmod +x src/gen.h.proc

make $MAKE_ARGS > second.out 2>&1
cat second.out

# The output was regenerated, this time by the new body of the script,
# and no pconfigure ran: the build heard about the edit through the
# file's mtime on the rule, which is the point.
if grep -q "^PCONFIGURE$" second.out
then
    exit 1
fi
grep -q "^GEN	gen.h$" second.out

# The consumer of the output recompiled and the binary relinked ...
grep -q "^CC	app.c$" second.out
grep -q "^LD	app$" second.out

# ... and the answer the binary gives is the new script's answer, the
# part a stale object would get wrong.
test "$(./bin/app)" = "142"

exit 0
