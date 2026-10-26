#include "harness_start.bash"

# A test's scratch directory is its compiled self's path with
# ".scratch" on the end, beside every other test of the same target.
# A sibling named exactly that -- "t" and "t.scratch" -- is compiled
# to the path "t" is handed as $PTEST_SCRATCH_DIR, so one of the two
# was always broken: ptest's mkdir found a program where the directory
# should be and "t" failed, or the program was copied into the
# directory and ptest was asked to run a directory.  It is refused
# instead, at the later of the two lines, so that which line is blamed
# never depends on which name happens to be the scratch.

mkdir -p src test/main

echo 'int main(void) { return 0; }' > src/main.c
echo 'int main(void) { return 0; }' > test/main/t.c
echo 'int main(void) { return 0; }' > test/main/u.c

cat >Configfile <<'EOF'
LANGUAGES += c

BINARIES  += main
SOURCES   += main.c
TESTS     += t
SOURCES   += t.c
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
grep -qF "Configfile:5 'TESTS += t'" configure.out
grep -q "scratch directory" configure.out

# The other way round is the same collision and the same refusal, of
# the line that came second.
cat >Configfile <<'EOF'
LANGUAGES += c

BINARIES  += main
SOURCES   += main.c
TESTS     += t.scratch
SOURCES   += u.c
TESTS     += t
SOURCES   += t.c
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS >configure.out 2>&1
then
    cat configure.out
    exit 1
fi
cat configure.out

head -n1 configure.out | grep -qF "Configfile:7 'TESTS += t'"
grep -qF "Configfile:5 'TESTS += t.scratch'" configure.out

# A name that only ends in ".scratch" is not reserved: with no "t"
# beside it nothing else wants that path, and it builds and runs like
# any other test.
cat >Configfile <<'EOF'
LANGUAGES += c

BINARIES  += main
SOURCES   += main.c
TESTS     += t.scratch
SOURCES   += u.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS check
test "$(tar -xOf check/main/t.scratch ptest__return)" = "0"
