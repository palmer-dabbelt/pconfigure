#include "harness_start.bash"

# 'asm' compiles '.c' as well as '.S', since a program with a little
# assembly in it is mostly C.  That makes it a second language able to
# build a target that is all C, and a project that turns 'asm' on for
# one program can't have every other C program in it start asking
# which of the two it meant: the C ones stay C, with C's "-x c" and no
# warning about a choice the Configfile never offered.

mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfile <<'EOF2'
LANGUAGES += c
LANGUAGES += asm

BINARIES  += main
SOURCES   += main.c
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
cat out
cat Makefile

if grep -q "Multiple valid languages" out
then
    exit 1
fi
grep -- "-x c .*src/main\.c" Makefile

make $MAKE_ARGS
./bin/main
