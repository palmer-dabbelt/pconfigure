#include "harness_start.bash"

mkdir -p src a/src b/src

# Two subprojects side by side, where one uses the other.  "a" reaches
# "b" by going up and back down, which is the only way it can name it.
cat >Configfile <<EOF
SUBPROJECTS += b
SUBPROJECTS += a

LANGUAGES += c

BINARIES  += test
LINKOPTS  += -La/lib
LINKOPTS  += -la
SOURCES   += test.c
EOF

cat >a/Configfile <<EOF
LANGUAGES += c

LIBRARIES += liba.so
LINKOPTS  += -L../b/lib
LINKOPTS  += -lb
SOURCES   += a.c
EOF

cat >b/Configfile <<EOF
LANGUAGES += c

LIBRARIES += libb.so
SOURCES   += b.c
EOF

cat >b/src/b.c <<EOF
int b(void) { return 41; }
EOF

cat >a/src/a.c <<EOF
int b(void);
int a(void) { return b() + 1; }
EOF

cat >src/test.c <<EOF
  #include <stdio.h>
int a(void);
int main(void) { printf("%d\n", a()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
cat a/Makefile

# "-L../b/lib" and "-Lb/lib" name the same directory, so the
# dependency gets found even though the two projects spell it
# differently.
grep -q "^a/obj/lib/liba.so/.*/local: b/lib/libb.so$" Makefile

# It's written in the top level, which is the nearest project that
# includes them both -- "a" has no idea how to build anything of
# "b"'s, so a dependency on one in a/Makefile would leave "a"
# unbuildable on its own.
if grep -q "libb.so" a/Makefile
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/test)" = "42"

# "a" still builds on its own, as far as it can: what it needs from
# "b" is already there, and it doesn't try to rebuild it.
cd a
rm -rf lib obj
make $MAKE_ARGS
test -f lib/liba.so
cd ..

exit 0
