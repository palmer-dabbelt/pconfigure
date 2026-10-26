#include "harness_start.bash"

# A script that globs a directory for its inputs is the case the
# build-time --deps fragment was added for: an input that arrives after
# the configure is picked up by the next make with no reconfigure.  An
# input that GOES is the other half.  The configure-time answer used to
# be written straight onto the rule, so the deleted file stayed a
# prerequisite that no rule builds, and every make from then on stopped
# with "No rule to make target" -- even though the script, asked again,
# no longer named it.
#
# Not failing is only half of it: the output encoded the deleted file,
# so the make after the deletion has to regenerate it, and the make
# after that has to have nothing left to do.

mkdir -p src/parts

echo 1 > src/parts/a.txt
echo 2 > src/parts/b.txt

cat >src/gen.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--deps)     for f in src/parts/*.txt
            do
                test -e "$f" && echo "$f"
            done ;;
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
LANGUAGES += c
GENERATE  += gen.h
BINARIES  += app
SOURCES   += app.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
timeout 60 make $MAKE_ARGS > first.out 2>&1 || { cat first.out; exit 1; }
cat first.out
test "$(./bin/app)" = "3"

# The first make found the answer the configure had already acted on,
# so it must not have regenerated anything to learn that.
if grep -q "^GEN	gen.h$" first.out
then
    exit 1
fi

sleep 2
rm src/parts/b.txt
timeout 60 make $MAKE_ARGS > second.out 2>&1 || { cat second.out; exit 1; }
cat second.out
grep -q "^GEN	gen.h$" second.out
test "$(./bin/app)" = "1"

timeout 60 make $MAKE_ARGS > settled.out 2>&1 || { cat settled.out; exit 1; }
cat settled.out
grep -q "Nothing to be done" settled.out
