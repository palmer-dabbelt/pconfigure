#include "harness_start.bash"

# A project that builds no libraries never creates its lib directory,
# so a "-L" naming it is a search path that isn't there.  Nobody wrote
# that flag down and nobody can take it out, which is what makes the
# linker's warning about it worth avoiding.
mkdir -p nolibs/src

cat >nolibs/Configfile <<EOF
LANGUAGES   += c

BINARIES    += test
SOURCES     += test.c
EOF

cat >nolibs/src/test.c <<EOF
int main(void) { return 0; }
EOF

cd nolibs
$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

if grep -q -- "-Llib" Makefile
then
    exit 1
fi

make $MAKE_ARGS
./bin/test
cd ..

# The same project with a library in it does get the "-L", since now
# there's something in there to find.
mkdir -p libs/src

cat >libs/Configfile <<EOF
LANGUAGES   += c

LIBRARIES   += liba.so
SOURCES     += a.c

BINARIES    += test
DEPLIBS     += a
SOURCES     += test.c
EOF

cat >libs/src/a.c <<EOF
int a(void) { return 42; }
EOF

cat >libs/src/test.c <<EOF
int a(void);
int main(void) { return a() == 42 ? 0 : 1; }
EOF

cd libs
$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

grep -q -- "-Llib" Makefile

make $MAKE_ARGS
./bin/test
cd ..

exit 0
