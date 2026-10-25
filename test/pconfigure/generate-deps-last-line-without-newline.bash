#include "harness_start.bash"

# A "--deps" answer whose last line has no newline on the end of it is
# still a complete answer: printf with no "\n" is the ordinary way a
# shell script prints a name, and "read" and sed both take that last
# line whole.  The configure-time read of the answer used to chop the
# final character off every line on the assumption that it was a
# newline, so the one line that had none lost a letter of its path
# instead, and the rule named an input that does not exist:
#
#     make: *** No rule to make target 'src/answer.tx', needed by
#     'obj/proc/gen.h'.  Stop.
#
# Two lines rather than one, so that the line that did end in a newline
# is checked to have come through untouched beside the one that did not.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h

BINARIES  += app
SOURCES   += app.c
EOF

echo 3 > src/base.txt
echo 5 > src/answer.txt

cat >src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     printf 'src/base.txt\nsrc/answer.txt' ;;
--generate) echo "#define ANSWER ($(cat src/base.txt) + $(cat src/answer.txt))" ;;
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

# The rule names both files the script printed, every letter of each.
grep -q "^obj/proc/gen.h: .*src/base.txt" Makefile
grep -q "^obj/proc/gen.h: .*src/answer.txt" Makefile
if grep -q "src/answer.tx\( \|$\)" Makefile
then
    exit 1
fi

timeout 60 make $MAKE_ARGS > first.out 2>&1 || { cat first.out; exit 1; }
cat first.out
test "$(./bin/app)" = "8"

# The fragment the build re-derives from the same answer reads it with
# sed rather than with the configure, and has to agree with it: a
# fragment that named the truncated file would stop every make that
# included it.
cat obj/proc/gen.h.d
grep -q "src/answer.txt" obj/proc/gen.h.d
if grep -q "src/answer.tx\( \|$\)" obj/proc/gen.h.d
then
    exit 1
fi

timeout 60 make $MAKE_ARGS > settled.out 2>&1 || { cat settled.out; exit 1; }
cat settled.out
grep -q "Nothing to be done" settled.out

# And the last line really is watched: an edit to it regenerates.
sleep 2
echo 6 > src/answer.txt
timeout 60 make $MAKE_ARGS > second.out 2>&1 || { cat second.out; exit 1; }
cat second.out
grep -q "^GEN	gen.h$" second.out
test "$(./bin/app)" = "9"

exit 0
