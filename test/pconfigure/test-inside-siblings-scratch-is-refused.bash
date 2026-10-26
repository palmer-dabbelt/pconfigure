#include "harness_start.bash"

# A TESTSRC can name a file in a directory of its own, and a directory
# called "t.bash.scratch" is the scratch directory of a sibling called
# "t.bash": the nested test would be compiled into the middle of the
# fixture its sibling keeps there, and "make clean" of the sibling
# would take it away.  That is refused like a test named after the
# scratch outright.  It is written as bash tests on purpose, since the
# rules for those come out of languages/bash.c++ rather than the
# languages/cxx.c++ the C tests elsewhere go through.

mkdir -p src test/main/t.bash.scratch

echo 'int main(void) { return 0; }' > src/main.c
echo 'true' > test/main/t.bash
echo 'true' > test/main/t.bash.scratch/inner.bash

cat >Configfile <<'EOF'
LANGUAGES += c
LANGUAGES += bash

BINARIES  += main
SOURCES   += main.c
TESTSRC   += t.bash
TESTSRC   += t.bash.scratch/inner.bash
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS >configure.out 2>&1
then
    cat configure.out
    exit 1
fi
cat configure.out

head -n1 configure.out | grep -qF "Configfile:7 'TESTSRC += t.bash.scratch/inner.bash'"
grep -qF "Configfile:6 'TESTSRC += t.bash'" configure.out
grep -q "scratch directory" configure.out
