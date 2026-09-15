#include "harness_start.bash"

# The same thing as subproject-deps-from-inside, one level further
# down.  A subproject two deep is named "a/b/..." from the top, "b/..."
# from inside "a", and "..." from inside itself -- three spellings of
# one path, and the fragment written for a source in there is read by
# whichever of the three builds comes next.
#
# So it is not enough for pdeps to know that it is somewhere other
# than the top.  It has to work out how far, and a project whose
# directory has more than one component in it is where a walk that
# counts wrongly stops being the same as a walk that counts at all.
mkdir -p src a/src a/b/src

cat >Configfile <<EOF
AUTORECONFIGURE = true

LANGUAGES   += c
SUBPROJECTS += a

BINARIES    += top
SOURCES     += top.c
EOF

cat >src/top.c <<'EOF'
int main(void) { return 0; }
EOF

cat >a/Configfile <<EOF
LANGUAGES   += c
SUBPROJECTS += b

BINARIES    += abin
SOURCES     += abin.c
EOF

cat >a/src/abin.c <<'EOF'
int main(void) { return 0; }
EOF

cat >a/b/Configfile <<EOF
LANGUAGES += c

BINARIES  += bbin
SOURCES   += bbin.c
EOF

# Named by no Configfile, and reachable only behind a header: what
# gets written for a source found this way is an "include" of its
# fragment, and make has to be able to resolve that to a file from
# wherever it is standing.
cat >a/b/src/buried.h <<'EOF'
int buried(void);
EOF

cat >a/b/src/buried.c <<'EOF'
int buried(void) { return 0; }
EOF

cat >a/b/src/bbin.c <<'EOF'
#include "buried.h"
int main(void) { return buried(); }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
./bin/top
./a/bin/abin
./a/b/bin/bbin

# The walk found the buried source, and the fragment names it through
# the variable rather than from where any one build was standing.
ls a/b/obj/src/bbin.c/*.d
grep -q 'include \$(pconfigure_subdir_a_b)obj/src/buried.c/' a/b/obj/src/bbin.c/*.d
cp a/b/obj/src/bbin.c/*.d from-the-top.d

##############################################################################
# Two levels down, which is a walk of two                                    #
##############################################################################
echo "int buried_other(void);" >> a/b/src/buried.h

(cd a/b && make $MAKE_ARGS && ./bin/bbin)

# Not one directory too high, and not one too low either.  A walk that
# went too far writes above the tree; one that did not go far enough
# leaves the project's own name on the front and creates it again
# underneath itself.
test ! -e a/b/a
test ! -e a/b/b
test ! -e a/b/obj/a

if grep -q "There is no such file today" a/b/obj/src/bbin.c/*.d
then
    cat a/b/obj/src/bbin.c/*.d
    exit 1
fi

if ! cmp from-the-top.d a/b/obj/src/bbin.c/*.d
then
    diff -u from-the-top.d a/b/obj/src/bbin.c/*.d || true
    exit 1
fi

##############################################################################
# One level down, which is a walk of one                                     #
##############################################################################
# From in here "b" is a subproject like any other, and the fragment
# for a source in it is spelled with one directory on the front rather
# than two.  The frozen spelling has two, so this is the case where
# what make said and what the context file says differ by some of the
# path rather than all of it.
echo "int buried_third(void);" >> a/b/src/buried.h

(cd a && make $MAKE_ARGS && ./b/bin/bbin)

test ! -e a/a
test ! -e a/b/a
test ! -e a/b/b

if ! cmp from-the-top.d a/b/obj/src/bbin.c/*.d
then
    diff -u from-the-top.d a/b/obj/src/bbin.c/*.d || true
    exit 1
fi

##############################################################################
# ... and the top still builds                                               #
##############################################################################
make $MAKE_ARGS
./bin/top
./a/bin/abin
./a/b/bin/bbin

exit 0
