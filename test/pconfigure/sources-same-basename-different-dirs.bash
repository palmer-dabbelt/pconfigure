#include "harness_start.bash"

# Two sources with the same file name in two directories are two
# sources, and the object directory mirrors the source tree for
# exactly that reason: an object named after its source's basename
# alone would have one of them overwrite the other and the link
# quietly lose a function.  Pinned here because nothing else in the
# suite has two sources sharing a name.
mkdir -p src/x src/y
echo 'int fx(void) { return 1; }' > src/x/util.c
echo 'int fy(void) { return 2; }' > src/y/util.c
cat >src/main.c <<'EOF'
int fx(void);
int fy(void);
int main(void) { return fx() + fy() == 3 ? 0 : 1; }
EOF

cat >Configfile <<EOF
LANGUAGES += c

BINARIES  += main
SOURCES   += x/util.c
SOURCES   += y/util.c
SOURCES   += main.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
./bin/main

test -d obj/src/x/util.c
test -d obj/src/y/util.c

# And editing one recompiles that one, not its namesake.
sleep 1
echo 'int fy(void) { return 2; } /* touched */' > src/y/util.c
make $MAKE_ARGS > out
cat out
grep -q "y/util.c" out
if grep -q "x/util.c" out
then
    exit 1
fi
./bin/main
