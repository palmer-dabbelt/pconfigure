#include "harness_start.bash"

# "GENERATE += ./gen.h" names the same file as "GENERATE += gen.h", and
# the file a consumer's '#include "gen.h"' finds is obj/proc/gen.h
# either way.  The rule was written as obj/proc/./gen.h, which make
# reads as a different target from the obj/proc/gen.h the object
# depends on, so an edited input regenerated the header and nothing
# recompiled against it: the binary went on printing the old answer
# with make exiting 0.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

GENERATE  += ./gen.h

BINARIES  += app
SOURCES   += app.c
EOF

echo 4 > src/answer.txt

cat >src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     echo "src/answer.txt" ;;
--generate) echo "#define ANSWER $(cat src/answer.txt)" ;;
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

# The rule has to be for the file the object depends on, by that
# file's own name.  This is the half of the test that doesn't depend
# on how make happens to schedule things.
grep -q '^obj/proc/gen.h:' Makefile
if grep -q 'proc/\./' Makefile
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/app)" = "4"

# Several edits in a row, and in parallel, because with no edge
# between the header and the object whether the object is looked at
# after the header was rewritten is down to scheduling.  A serial make
# happens to walk "all" in an order that gets it right; with -j2 every
# other edit was missed.
for n in 5 6 7 8
do
    sleep 2
    echo $n > src/answer.txt
    make $MAKE_ARGS -j2
    grep -q "define ANSWER $n" obj/proc/gen.h
    test "$(./bin/app)" = "$n"
done

exit 0
