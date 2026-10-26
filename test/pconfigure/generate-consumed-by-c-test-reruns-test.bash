#include "harness_start.bash"

# A compiled test reading a generated header: the test's object depends
# on the header, so when the generator's input changes the test is
# rebuilt and its result recomputed by the next make check, rather than
# the old verdict standing.  The verdict is read out of the result
# itself, since make check failing would also be what a build error in
# the test looks like.

mkdir -p src test/app

cat >Configfile <<EOF
LANGUAGES += c
GENERATE  += gen.h
BINARIES  += app
SOURCES   += app.c
TESTSRC   += expect.c
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

cat >src/app.c <<'EOF'
int main(void) { return 0; }
EOF

cat >test/app/expect.c <<'EOF'
#include "gen.h"
int main(void) { return V == 1 ? 0 : 1; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS check
test "$(tar -xOf check/app/expect.c ptest__return)" = "0"

sleep 2
echo 2 > src/in.txt
if make $MAKE_ARGS check
then
    exit 1
fi
test "$(tar -xOf check/app/expect.c ptest__return)" = "1"
grep -q "^#define V 2$" obj/proc/gen.h

exit 0
