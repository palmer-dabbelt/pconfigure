#include "harness_start.bash"

# The subproject half of this already works: deleting "sub/obj" takes
# the Makefile pconfigure wrote for the subproject, and the rule for
# that missing Makefile is a pconfigure run that puts back everything
# else in there too.  Deleting the top object directory instead leaves
# every Makefile in place, so that rule never fires -- and what went
# with the directory was the top project's own configure-time files,
# which nothing else puts back.

export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src sub/src

cat >Configfile <<'EOF'
AUTORECONFIGURE  = true
SUBPROJECTS     += sub
LANGUAGES       += c
BINARIES        += top
SOURCES         += top.c
EOF

cat >sub/Configfile <<'EOF'
LANGUAGES       += c
BINARIES        += subbin
SOURCES         += sub.c
EOF

echo 'int main(void) { return 0; }' > src/top.c
echo 'int main(void) { return 0; }' > sub/src/sub.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test -x bin/top

# The subproject's way still works, which is what makes the other one
# a gap rather than a rule.
rm -rf sub/obj
make $MAKE_ARGS > sub.log 2>&1 || { cat sub.log; exit 1; }
cat sub.log
test -x sub/bin/subbin

rm -rf obj
make $MAKE_ARGS > top.log 2>&1 || { cat top.log; exit 1; }
cat top.log
test -x bin/top

# And it settles, so whatever brought the files back is not something
# every make goes on doing.
make $MAKE_ARGS > settled.log 2>&1 || { cat settled.log; exit 1; }
cat settled.log
grep -q "Nothing to be done" settled.log

exit 0
