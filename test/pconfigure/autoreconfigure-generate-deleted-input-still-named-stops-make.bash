#include "harness_start.bash"

# The other side of letting a deleted --deps input go quietly: an input
# the script STILL names is mandatory, and a mandatory input that is
# missing is a build that cannot be right, so make has to stop on it
# rather than generate the output without it.  What makes the
# difference is whether the script, asked again, still says the name --
# not whether the configure once heard it.
#
# Under AUTORECONFIGURE, because there the output is wanted while make
# is still remaking the fragments it includes, so the fragment it holds
# at that point is the one from before the deletion, which knew the
# input as present.

mkdir -p src/parts

echo 1 > src/parts/a.txt
echo 2 > src/parts/b.txt

cat >src/gen.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--deps)     echo src/parts/a.txt
            echo src/parts/b.txt ;;
--generate) echo "#define V ($(cat src/parts/*.txt | paste -sd+ -))" ;;
esac
exit 0
EOF
chmod +x src/gen.h.proc

cat >src/app.c <<'EOF'
#include "gen.h"
#include <stdio.h>
int main(void) { printf("%d\n", V); return 0; }
EOF

cat >Configfile <<EOF
AUTORECONFIGURE = true
LANGUAGES += c
GENERATE  += gen.h
BINARIES  += app
SOURCES   += app.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
timeout 60 make $MAKE_ARGS > first.out 2>&1 || { cat first.out; exit 1; }
cat first.out
test "$(./bin/app)" = "3"

sleep 2
rm src/parts/b.txt
if timeout 60 make $MAKE_ARGS > second.out 2>&1
then
    cat second.out
    exit 1
fi
cat second.out
grep -q "No rule to make target 'src/parts/b.txt'" second.out

# Stopping is not enough by itself: it has to stop BEFORE the output is
# generated without the input.  The fragment in force at this point was
# written while b.txt was there, and one that let a vanished input count
# as made let gen.h be regenerated from a.txt alone, and only then did
# make stop.  The error looked right; the gen.h left behind was wrong.
# The rule may get as far as announcing itself, but not as far as
# running the script.
grep -qxF '#define V (1+2)' obj/proc/gen.h

# And it goes on stopping, rather than letting the next make find the
# fragment up to date and carry on without the input.
if timeout 60 make $MAKE_ARGS > third.out 2>&1
then
    cat third.out
    exit 1
fi
cat third.out
grep -q "No rule to make target 'src/parts/b.txt'" third.out
grep -qxF '#define V (1+2)' obj/proc/gen.h

# Putting it back as it was, mtime and all -- the way a "cp -p" or an
# "mv" from a backup or an "rsync -t" does -- leaves nothing newer than
# gen.h and an answer the record already holds, so nothing would notice
# a gen.h that had been rewritten without it.  It has to still be the
# one generated with it.
echo 2 > b.txt.saved
touch -t 202001010000 b.txt.saved
mv b.txt.saved src/parts/b.txt
timeout 60 make $MAKE_ARGS > fourth.out 2>&1 || { cat fourth.out; exit 1; }
cat fourth.out
test "$(./bin/app)" = "3"

# And an edit to it is heard as usual.
sleep 2
echo 4 > src/parts/b.txt
timeout 60 make $MAKE_ARGS > fifth.out 2>&1 || { cat fifth.out; exit 1; }
cat fifth.out
test "$(./bin/app)" = "5"
