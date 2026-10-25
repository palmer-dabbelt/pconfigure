#include "harness_start.bash"

# The day-to-day shape of the object-hash split: somebody works inside
# a submodule with its own Makefile and builds the whole tree from the
# top now and then.  Once both have built, every edit to a source is
# compiled, linked and copied into place twice -- once by whichever
# side builds first and again by the other, which finds its own
# differently-named object out of date.  The manual promises one
# build's output is the other's.
mkdir -p sub/src

cat >Configfile <<'EOF'
SUBPROJECTS += sub
EOF

cat >sub/Configfile <<'EOF'
LANGUAGES += c
LIBRARIES += libpart.so
SOURCES   += part.c
EOF

echo 'int part(void) { return 1; }' > sub/src/part.c

$PTEST_BINARY $PCONFIGURE_ARGS
(cd sub && $PTEST_BINARY $PCONFIGURE_ARGS)

make $MAKE_ARGS
(cd sub && make $MAKE_ARGS)

# Settled from both sides before the edit, so that what follows is
# about the edit alone.
sleep 1
echo 'int part(void) { return 2; }' > sub/src/part.c

make $MAKE_ARGS > top.out 2>&1
cat top.out
grep -q "^CC	part.c$" top.out

(cd sub && make $MAKE_ARGS) > inside.out 2>&1
cat inside.out
if grep -q "^CC	\|^LD	\|^CP	" inside.out
then
    exit 1
fi

exit 0
