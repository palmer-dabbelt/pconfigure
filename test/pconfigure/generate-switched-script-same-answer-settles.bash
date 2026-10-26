#include "harness_start.bash"

# Pointing a GENERATE at a different script is a reason to run that
# script, but not a reason to rebuild what reads the output when the
# new script prints exactly what the old one did -- the same "is the
# answer any different?" the rule asks of every regeneration.  And it
# has to be asked once: a record of the recipe that ended up newer
# than an output the regeneration left alone would have make run the
# script again on every build after the switch, forever.

mkdir -p src test

for dir in src test
do
    cat >$dir/gen.h.proc <<EOF
#!/bin/sh
case "\$1" in
--generate) echo $dir >> generate-runs; echo "#define V 1" ;;
esac
EOF
    chmod +x $dir/gen.h.proc
done

cat >src/app.c <<'EOF'
#include "gen.h"
#include <stdio.h>
int main(void) { printf("%d\n", V); return 0; }
EOF

cat >Configfile <<EOF
LANGUAGES += c
GENERATE  += gen.h
BINARIES  += app
SOURCES   += app.c
EOF

sleep 2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "1"
test "$(grep -c test generate-runs)" = "0"

touch before-switch
sed -i 's/^GENERATE /TGENERATE /' Configfile
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS > switched.out 2>&1
cat switched.out
test "$(./bin/app)" = "1"

# The new script has been run, and the program that reads its output
# was not rebuilt for an answer that did not change.
test "$(grep -c test generate-runs)" -ge 1
test -z "$(find bin/app obj/proc/gen.h -newer before-switch)"

# And it stays settled: neither another make nor another configure
# runs anything.
cp generate-runs generate-runs.settled
make $MAKE_ARGS > again.out 2>&1
cat again.out
grep -q "Nothing to be done" again.out
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS > reconfigured.out 2>&1
cat reconfigured.out
grep -q "Nothing to be done" reconfigured.out
cmp generate-runs generate-runs.settled

exit 0
