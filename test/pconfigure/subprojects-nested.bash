#include "harness_start.bash"

mkdir -p src a/src a/b/src

# Three levels: the top pulls in "a", which pulls in "b".  Nothing in
# "a" knows whether it's being built on its own or as part of the top.
cat >Configfile <<EOF
SUBPROJECTS += a

LANGUAGES   += c

BINARIES    += test
COMPILEOPTS += -Ia/include
LINKOPTS    += -La/lib
LINKOPTS    += -la
SOURCES     += test.c
EOF

cat >a/Configfile <<EOF
SUBPROJECTS += b

LANGUAGES += c
LANGUAGES += bash
LANGUAGES += h

HEADERSRC += a.h

LIBRARIES += liba.so
COMPILEOPTS += -Ib/include
LINKOPTS  += -Lb/lib
LINKOPTS  += -lb
SOURCES   += a.c
EOF

cat >a/b/Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash
LANGUAGES += h

HEADERSRC += b.h

LIBRARIES += libb.so
SOURCES   += b.c
EOF

cat >a/src/a.h <<EOF
int a(void);
EOF

cat >a/b/src/b.h <<EOF
int b(void);
EOF

cat >a/src/a.c <<EOF
  #include <b.h>
int a(void) { return b() + 1; }
EOF

cat >a/b/src/b.c <<EOF
int b(void) { return 41; }
EOF

cat >src/test.c <<EOF
  #include <a.h>
  #include <stdio.h>
int main(void) { printf("%d\n", a()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
cat a/Makefile
cat a/b/Makefile

# Every project gets a Makefile, and each one includes its own
# children rather than the top including all of them.
test -f a/Makefile
test -f a/b/Makefile
grep -q "^pconfigure_subdir_a ?= a/$" Makefile
grep -q "^pconfigure_subdir_a_b ?= \$(pconfigure_subdir_a)b/$" a/Makefile
if grep -q "pconfigure_subdir_a_b" Makefile
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/test)" = "42"

# The dependency the top level has on "a" is written where the top
# level can see it...
grep -q "^obj/bin/test/.*/local: a/lib/liba.so$" Makefile

# ... and the one between the two subprojects is written in the
# nearest project that includes them both, spelled so that it means
# the same thing whether make was run there or above it.  That's what
# keeps "a" correct when it's built on its own.
grep -q "^\$(pconfigure_subdir_a)obj/lib/liba.so/.*/local: \$(pconfigure_subdir_a)b/lib/libb.so$" a/Makefile
grep -q "^\$(pconfigure_subdir_a)obj/check-all-done: \$(pconfigure_subdir_a)b/obj/check-all-done$" a/Makefile

# The middle project builds on its own, and pulls in its own
# subproject when it does.
cd a
rm -rf lib include obj b/lib b/include b/obj
make $MAKE_ARGS
test -f lib/liba.so
test -f b/lib/libb.so
test -f b/include/b.h
cd ..

# The deepest project builds on its own too.
cd a/b
rm -rf lib include obj
make $MAKE_ARGS
test -f lib/libb.so
cd ../..

# ... and the top level still works afterwards.
make $MAKE_ARGS
test "$(./bin/test)" = "42"

# Installing from the top installs all three, into one prefix.
make $MAKE_ARGS D=$(pwd)/install DESTDIR=$(pwd)/install install
test -f install/usr/local/bin/test
test -f install/usr/local/lib/liba.so
test -f install/usr/local/lib/libb.so
test -f install/usr/local/include/a.h
test -f install/usr/local/include/b.h

exit 0
