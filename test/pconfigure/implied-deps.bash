#include "harness_start.bash"

# Note that there's deliberately no "DEPLIBS +=" anywhere here: the
# "-l" flags on the link lines are all pconfigure needs to work out
# that the binaries depend on the libraries.  "-lm" is in there to
# check that a library nothing in this project builds is left alone.
cat >Configfile <<EOF
LANGUAGES   += c

LIBRARIES   += liba.so
SOURCES     += a.c

LIBRARIES   += libb.so
SOURCES     += b.c

BINARIES    += test
LINKOPTS    += -la
LINKOPTS    += -lm
SOURCES     += test.c

BINARIES    += split
LINKOPTS    += -L lib
LINKOPTS    += -l b
SOURCES     += split.c
EOF

mkdir -p src

cat >src/a.c <<EOF
int a(void) { return 42; }
EOF

cat >src/b.c <<EOF
int b(void) { return 24; }
EOF

cat >src/test.c <<EOF
int a(void);
int main(void) { return a() == 42 ? 0 : 1; }
EOF

cat >src/split.c <<EOF
int b(void);
int main(void) { return b() == 24 ? 0 : 1; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS

# The dependency shows up in the Makefile even though nothing wrote it
# down, and the binaries that come out actually link.
grep -q "^obj/bin/test/.*/local: lib/liba.so$" Makefile
./bin/test

# "-L dir" and "-l name" work the same as "-Ldir" and "-lname".
grep -q "^obj/bin/split/.*/local: lib/libb.so$" Makefile
./bin/split

# A library that nothing here builds doesn't turn into a dependency on
# a target that doesn't exist.
if grep -q "libm\.\(so\|dylib\|a\)$" Makefile
then
    exit 1
fi

# ... and it's a real dependency, not just a comment: asking for the
# binary alone is enough to get the library built first.
rm -f bin/test lib/liba.so
make $MAKE_ARGS bin/test
test -f lib/liba.so
./bin/test

exit 0
