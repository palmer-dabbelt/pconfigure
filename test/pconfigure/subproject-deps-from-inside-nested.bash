#include "harness_start.bash"

# The same thing as subproject-deps-from-inside, one level further
# down.  A subproject two deep is named "a/b/..." from the top, "b/..."
# from inside "a", and "..." from inside itself -- three spellings of
# one path, and a tree configured at all three places has three builds
# that each describe this one source from a different distance.
#
# So it is not enough for pdeps to know that it is somewhere other
# than the top.  It has to work out how far, and a project whose
# directory has more than one component in it is where a walk that
# counts wrongly stops being the same as a walk that counts at all.
#
# Three configures means three of everything a configure writes, and
# what keeps them apart is the project's name on the end of each of
# them.  Share one and the build that did not write it reads a set of
# paths measured from somewhere it is not standing.
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
# Said at each level rather than only at the top, because each of the
# three builds below is configured where it runs, and a configure has
# no parent to inherit this from once it is the top of its own run.
AUTORECONFIGURE = true

LANGUAGES   += c
SUBPROJECTS += b

BINARIES    += abin
SOURCES     += abin.c
EOF

cat >a/src/abin.c <<'EOF'
int main(void) { return 0; }
EOF

cat >a/b/Configfile <<EOF
AUTORECONFIGURE = true

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
# the variable that says where this project is as the build that wrote
# it sees things -- which from up here is two directories away.
test "$(ls a/b/obj/src/bbin.c/*.d | wc -l)" -eq 1
from_the_top="$(echo a/b/obj/src/bbin.c/*.d)"
grep -q "^include \$(pconfigure_subdir_a_b)obj/src/buried.c/" "$from_the_top"
cp "$from_the_top" from-the-top.d

##############################################################################
# Two levels down, which is a walk of two                                    #
##############################################################################
echo "int buried_other(void);" >> a/b/src/buried.h

(cd a/b && $PTEST_BINARY $PCONFIGURE_ARGS)
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

# A second fragment, spelled from where this build was standing, and
# the first one untouched.
test "$(ls a/b/obj/src/bbin.c/*.d | wc -l)" -eq 2
from_b="$(ls a/b/obj/src/bbin.c/*.d | grep -v -x -F "$from_the_top")"
grep -q "^include obj/src/buried.c/" "$from_b"

if ! cmp from-the-top.d "$from_the_top"
then
    diff -u from-the-top.d "$from_the_top" || true
    exit 1
fi

##############################################################################
# One level down, which is a walk of one                                     #
##############################################################################
# From in here "b" is a subproject like any other, and the fragment
# for a source in it is spelled with one directory on the front rather
# than two.  This is the case where two of the three answers differ by
# some of the path rather than all of it, which is the one a name
# built out of anything less than the whole directory would collide
# on.
echo "int buried_third(void);" >> a/b/src/buried.h

(cd a && $PTEST_BINARY $PCONFIGURE_ARGS)
(cd a && make $MAKE_ARGS && ./b/bin/bbin)

test ! -e a/a
test ! -e a/b/a
test ! -e a/b/b

# Three fragments now, one per build, each measured from where its
# build was standing -- and the two written earlier still saying what
# they said.
test "$(ls a/b/obj/src/bbin.c/*.d | wc -l)" -eq 3
from_a="$(ls a/b/obj/src/bbin.c/*.d \
          | grep -v -x -F "$from_the_top" | grep -v -x -F "$from_b")"
cat "$from_a"
grep -q "^include \$(pconfigure_subdir_b)obj/src/buried.c/" "$from_a"
grep -q "^include obj/src/buried.c/" "$from_b"

if ! cmp from-the-top.d "$from_the_top"
then
    diff -u from-the-top.d "$from_the_top" || true
    exit 1
fi

##############################################################################
# ... and the top still builds, into the right directories                   #
##############################################################################
make $MAKE_ARGS
./bin/top
./a/bin/abin
./a/b/bin/bbin

# Each project's fragments are where that project is.  A build reading
# a context some other build wrote measures from the wrong distance,
# and "the wrong distance" here is one directory or two depending on
# which pair of runs shared the file.
test -e obj/src/top.c
test ! -e obj/src/bbin.c
test ! -e a/obj/src/bbin.c
test ! -e a/b/obj/a

exit 0
