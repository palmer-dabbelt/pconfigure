#include "harness_start.bash"

# A glob character in a target's name builds and cleans on its own,
# but only because there is nothing for it to match.  Beside a second
# program whose name it does match there is: make expands "a?b" in a
# rule's target against the files that exist, so the two programs'
# rules land on the same files ("overriding recipe"), and the shell
# expands it in the recipes, so a cp gets both programs' links.  So
# every glob character warns, naming the line it's on, whether or not
# a sibling happens to be there yet -- the second program is usually
# written long after the first.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += c

BINARIES  += a?b
SOURCES   += one.c

BINARIES  += axb
SOURCES   += two.c
EOF

cat >src/one.c <<'EOF'
int main(void) { return 1; }
EOF

cat >src/two.c <<'EOF'
int main(void) { return 2; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
cat configure.out
grep -q "Configfile:3" configure.out
grep -qF "warning: BINARIES has a '?' in it: 'a?b'" configure.out
test "$(grep -c "warning:" configure.out)" = 1

# The other two glob characters, each alone in a project with nothing
# for it to match, which is the case that builds today and has to go
# on building.
for name in 'a*b' 'a[b'
do
    rm -rf alone
    mkdir -p alone/src
    cp src/one.c alone/src/
    cat >alone/Configfile <<EOF
LANGUAGES += c
BINARIES  += $name
SOURCES   += one.c
EOF
    (cd alone && $PTEST_BINARY $PCONFIGURE_ARGS) > alone.out 2>&1
    cat alone.out
    grep -q "Configfile:2" alone.out
    grep -qF "warning: BINARIES has a '${name:1:1}' in it: '$name'" alone.out
    (cd alone && make $MAKE_ARGS)
    test -x "alone/bin/$name"
done

# And the colliding pair is refused outright by a project that asked
# for it, at the line, before anything gets the chance to overwrite
# anything.
mkdir -p strict/src
cp src/one.c src/two.c strict/src/
( echo "STRICT     = v0.13"; cat Configfile ) > strict/Configfile

if (cd strict && $PTEST_BINARY $PCONFIGURE_ARGS) > strict.out 2>&1
then
    cat strict.out
    exit 1
fi
cat strict.out
grep -q "Configfile:4" strict.out
grep -qF "error: BINARIES has a '?' in it" strict.out
test ! -e strict/Makefile

exit 0
