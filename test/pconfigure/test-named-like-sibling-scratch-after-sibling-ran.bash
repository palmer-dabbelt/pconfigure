#include "harness_start.bash"

# The collision of a test named after a sibling's scratch directory,
# arrived at the way it usually is: "t" has already run, so its
# scratch directory exists with whatever it kept there, and then a
# test called "t.scratch" is added.  Building that one used to copy
# the compiled test into t's scratch directory and hand ptest the
# directory to run -- an EROR caused by an older test having run,
# which nothing in the Configfile explains.  It is refused at its
# line instead, and t's fixture is left where it was.

mkdir -p src test/main

cat >Configfile <<'EOF'
LANGUAGES += c

BINARIES  += main
SOURCES   += main.c
TESTS     += t
SOURCES   += t.c
EOF

echo 'int main(void) { return 0; }' > src/main.c
echo 'int main(void) { return 0; }' > test/main/t.c
echo 'int main(void) { return 0; }' > test/main/u.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS check
test "$(tar -xOf check/main/t ptest__return)" = "0"
test -d obj/check/main/t.scratch
echo kept > obj/check/main/t.scratch/fixture

cat >>Configfile <<'EOF'
TESTS     += t.scratch
SOURCES   += u.c
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS >configure.out 2>&1
then
    cat configure.out
    exit 1
fi
cat configure.out

head -n1 configure.out | grep -qF "Configfile:7 'TESTS += t.scratch'"
test "$(cat obj/check/main/t.scratch/fixture)" = "kept"
