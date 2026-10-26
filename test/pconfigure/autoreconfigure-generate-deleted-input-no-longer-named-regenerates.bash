#include "harness_start.bash"

# The same deleted input under AUTORECONFIGURE, which is the mode that
# promises the build keeps its own dependencies current.  It did not
# help: the Makefile is not remade, because nothing the Makefile
# depends on changed, so the stale prerequisite the configure wrote
# stayed on the rule and make stopped on it.

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
timeout 60 make $MAKE_ARGS > second.out 2>&1 || { cat second.out; exit 1; }
cat second.out
test "$(./bin/app)" = "1"

timeout 60 make $MAKE_ARGS > settled.out 2>&1 || { cat settled.out; exit 1; }
cat settled.out
grep -q "Nothing to be done" settled.out
