#include "harness_start.bash"

# A quoted include looks in the includer's own directory before any
# -I, so when src/ has a gen.h of its own the compiler reads that one
# and not the GENERATE output of the same name.  pconfigure's scan has
# to pick the same file, or the object depends on a header the
# compiler never opens: this pins that editing src/gen.h rebuilds the
# program, and that the generated one, which nothing reads, doesn't.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c
GENERATE  += gen.h
BINARIES  += app
SOURCES   += app.c
EOF

echo 1 > src/in.txt

cat >src/gen.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--deps)     echo "src/in.txt" ;;
--generate) echo "#define V $(cat src/in.txt)" ;;
esac
EOF
chmod +x src/gen.h.proc

echo "#define V 5" > src/gen.h

cat >src/app.c <<'EOF'
#include "gen.h"
#include <stdio.h>
int main(void) { printf("%d\n", V); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "5"

sleep 2
echo "#define V 6" > src/gen.h
make $MAKE_ARGS > edit.out 2>&1
cat edit.out
grep -q "^CC	app.c$" edit.out
test "$(./bin/app)" = "6"

sleep 2
echo 9 > src/in.txt
make $MAKE_ARGS > gen.out 2>&1
cat gen.out
if grep -q "^CC	app.c$" gen.out
then
    exit 1
fi
test "$(./bin/app)" = "6"

exit 0
