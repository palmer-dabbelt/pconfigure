#include "harness_start.bash"

# An input the script stops naming makes the output out of date, since
# the output may well have said something the input said.  When it
# turns out not to have, the regenerated output compares equal and is
# left alone so that nothing downstream rebuilds -- and that must not
# leave the output older than whatever said "the answer changed", or
# every make from then on runs the script again to learn the same
# thing.  Here the script only counts the inputs that are not empty, so
# deleting the empty one changes the answer and not the output.

mkdir -p src/parts

echo 1 > src/parts/a.txt
: > src/parts/empty.txt

cat >src/gen.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--deps)     for f in src/parts/*.txt
            do
                test -e "$f" && echo "$f"
            done ;;
--generate) n=0
            for f in src/parts/*.txt
            do
                test -s "$f" && n=$((n + 1))
            done
            echo "#define V $n" ;;
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
test "$(./bin/app)" = "1"

sleep 2
rm src/parts/empty.txt
timeout 60 make $MAKE_ARGS > second.out 2>&1 || { cat second.out; exit 1; }
cat second.out
grep -q "^GEN	gen.h$" second.out
if grep -q "^CC	app.c$" second.out
then
    exit 1
fi
test "$(./bin/app)" = "1"

timeout 60 make $MAKE_ARGS > settled.out 2>&1 || { cat settled.out; exit 1; }
cat settled.out
grep -q "Nothing to be done" settled.out
