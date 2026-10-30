#include "harness_start.bash"

# The same question for CROSS_COMPILE: a subproject that only groups
# others builds nothing with the toolchain it was handed, so a late
# CROSS_COMPILE in the parent is judged by the libraries under it.
# Here the one library names the toolchain itself, so the parent
# naming the same one afterwards builds everything one way and is
# left alone.
#
# Nothing here gets far enough to run a compiler, so the toolchain
# named doesn't have to exist.
mkdir -p src a/b/src

cat >Configfile <<'EOF'
SUBPROJECTS   += a
CROSS_COMPILE  = faketc-
LANGUAGES     += c
BINARIES      += main
SOURCES       += main.c
EOF

cat >a/Configfile <<'EOF'
SUBPROJECTS += b
EOF

cat >a/b/Configfile <<'EOF'
CROSS_COMPILE  = faketc-
LANGUAGES     += c
LIBRARIES     += libb.so
SOURCES       += b.c
EOF

echo 'int b(void) { return 3; }' > a/b/src/b.c
echo 'int main(void) { return 0; }' > src/main.c

$PTEST_BINARY $PCONFIGURE_ARGS
test -f Makefile

# Without that line the library is built for this machine, the way the
# group was handed it, and the parent's CROSS_COMPILE splits from it.
rm -f Makefile
sed -i.bak '/^CROSS_COMPILE/d' a/b/Configfile
if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
then
    cat configure.out
    exit 1
fi
cat configure.out

grep -q "^\./Configfile:2 'CROSS_COMPILE = faketc-'" configure.out
grep -q "the subproject 'a' was already read, and its library 'libb.so' is built for this machine" configure.out
grep -q "that library was asked for at a/b/Configfile:2 'LIBRARIES += libb.so'" configure.out
test ! -e Makefile
