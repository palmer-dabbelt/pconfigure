#include "harness_start.bash"

# The other side of the rule that a SUBPROJECTS may not climb out of
# its project: a ".." that comes back down inside the same project
# climbs out of nothing.  "x/../b" written in "a" is a's own "b", from
# the top and from inside "a" alike, and is read as exactly that --
# once, under b's own name, however it was spelled.
mkdir -p a/b/src a/x

echo "SUBPROJECTS += a" > Configfile

cat >a/Configfile <<EOF
SUBPROJECTS += x/../b
EOF

cat >a/b/Configfile <<EOF
LANGUAGES   += c
LIBRARIES   += libb.so
SOURCES     += b.c
EOF
echo 'int b(void) { return 0; }' > a/b/src/b.c

$PTEST_BINARY $PCONFIGURE_ARGS
test -f a/b/obj/Makefile.a.b
grep -q "^pconfigure_subdir_a_b ?= \$(pconfigure_subdir_a)b/$" a/obj/Makefile.a
make $MAKE_ARGS
test -f a/b/lib/libb.so

(cd a && $PTEST_BINARY $PCONFIGURE_ARGS)
test -f a/b/obj/Makefile.b
(cd a && make $MAKE_ARGS)

exit 0
