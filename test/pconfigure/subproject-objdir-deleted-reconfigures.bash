#include "harness_start.bash"

# A subproject's object directory deleted out from under a configured
# AUTORECONFIGURE tree comes back on the next make.
#
# The Makefile a parent includes for each subproject lives in that
# subproject's object directory, and a configure is the only thing
# that writes it.  So deleting the directory -- by hand, or by running
# a vendored tree's own bootstrap.sh, which starts from an empty one --
# used to leave
#
#     make: *** No rule to make target 'sub/obj/Makefile.sub'.  Stop.
#
# on every make after, in a tree whose Configfiles had not changed and
# whose answer was one configure away.  A grandchild's Makefile is
# included from its parent's rather than from the top, so it is
# deleted and asserted separately: a fix that only covered the top's
# own children would pass the first half of this.

mkdir -p src sub/src sub/nested/src

cat >Configfile <<'EOF'
AUTORECONFIGURE  = true
SUBPROJECTS     += sub
LANGUAGES       += c
BINARIES        += top
SOURCES         += top.c
EOF

cat >sub/Configfile <<'EOF'
SUBPROJECTS     += nested
LANGUAGES       += c
BINARIES        += subbin
SOURCES         += sub.c
EOF

cat >sub/nested/Configfile <<'EOF'
LANGUAGES       += c
BINARIES        += nestedbin
SOURCES         += nested.c
EOF

for f in src/top.c sub/src/sub.c sub/nested/src/nested.c
do
    echo 'int main(void) { return 0; }' > "$f"
done

$PTEST_BINARY $PCONFIGURE_ARGS
timeout 60 make $MAKE_ARGS > first.out 2>&1 || { cat first.out; exit 1; }
cat first.out
timeout 60 make $MAKE_ARGS > settled.out 2>&1 || { cat settled.out; exit 1; }
cat settled.out
grep -q "Nothing to be done" settled.out

# The rule is there and it does nothing while the file is: a settled
# tree stayed settled above, with the rule in place, which is what "no
# prerequisites" was for.
test -x sub/bin/subbin
test -x sub/nested/bin/nestedbin

# The child.
rm -rf sub/obj
timeout 60 make $MAKE_ARGS > child.out 2>&1 || { cat child.out; exit 1; }
cat child.out
test "$(grep -c "^PCONFIGURE$" child.out)" -eq 1
test -x sub/bin/subbin
timeout 60 make $MAKE_ARGS > child-settled.out 2>&1 || {
    cat child-settled.out; exit 1; }
cat child-settled.out
grep -q "Nothing to be done" child-settled.out

# The grandchild.
rm -rf sub/nested/obj
timeout 60 make $MAKE_ARGS > nested.out 2>&1 || { cat nested.out; exit 1; }
cat nested.out
test "$(grep -c "^PCONFIGURE$" nested.out)" -eq 1
test -x sub/nested/bin/nestedbin
timeout 60 make $MAKE_ARGS > nested-settled.out 2>&1 || {
    cat nested-settled.out; exit 1; }
cat nested-settled.out
grep -q "Nothing to be done" nested-settled.out

exit 0
