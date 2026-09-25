#include "harness_start.bash"

# A script that discovers its inputs -- a glob over a directory, most
# often -- has inputs that can arrive after the configure.  The
# "--deps" answer pconfigure got names what the script read when
# pconfigure ran, and the file that arrived later is on no rule from
# it: nothing in the Makefile moves when it appears, and the output
# sits there quietly out of date until somebody reconfigures by hand.
# The snapshot is a last word only if the build never asks the script
# again, so the dep report is re-derived during builds (the way pdeps
# re-derives a source's deps), and the file that arrives lands on the
# rule through the re-derived answer -- heard by the same plain make.
#
# What this pins that the script-edit test does not: the regeneration
# riding on the arrival of an input the configure-time answer could
# not have named, rather than on the mtime of anything pconfigure
# already knew about.

mkdir -p src/inputs

cat >Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h

BINARIES  += app
SOURCES   += app.c
EOF

echo 1 > src/inputs/first.txt

cat >src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     for f in src/inputs/*.txt; do echo "$f"; done ;;
--generate) echo "#define COUNT $(ls src/inputs/*.txt | wc -l)" ;;
esac
EOF
chmod +x src/gen.h.proc

cat >src/app.c <<'EOF'
  #include "gen.h"
  #include <stdio.h>
int main(void) { printf("%d\n", COUNT); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS > first.out 2>&1
cat first.out
test "$(./bin/app)" = "1"

# A build that has nothing to do is the ordinary answer from here on,
# which is what makes the build after the arrival mean something.
make $MAKE_ARGS > settled.out 2>&1
cat settled.out
grep -q "Nothing to be done" settled.out

##############################################################################
# A second input appears in the directory the script globs                   #
##############################################################################
sleep 2
echo 2 > src/inputs/second.txt

make $MAKE_ARGS > second.out 2>&1
cat second.out

# No reconfigure ran: this was the same plain make, and the arrival
# was heard about through the dep report being re-derived, which is
# the point.
if grep -q "^PCONFIGURE$" second.out
then
    exit 1
fi

# The dep report was re-derived during the build, and the file that
# was not there at configure time is on the rule now.
grep -q "^DEPS	gen.h$" second.out

# The output was regenerated, and the consumers with it.
grep -q "^GEN	gen.h$" second.out
grep -q "^CC	app.c$" second.out
grep -q "^LD	app$" second.out

# And the binary counts the file that was not there when pconfigure
# ran, the part a stale output would get wrong.
test "$(./bin/app)" = "2"

# Then it settles again: the re-derivation ran when the input
# arrived, not forever after.
make $MAKE_ARGS > third.out 2>&1
cat third.out
grep -q "Nothing to be done" third.out

exit 0
