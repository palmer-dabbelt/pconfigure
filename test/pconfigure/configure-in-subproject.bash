#include "harness_start.bash"

# A subproject's Makefile is written to work both ways: a parent
# includes it, and it can also be built where it sits.  What makes
# that possible is the variable at the top of it, which the parent
# sets to the subproject's directory and the file defaults to nothing.
#
# Running pconfigure inside the subproject writes a Makefile with no
# variable in it at all, because from down there the project is the
# top of the tree and has no directory to be found through.  The file
# still gets included by the parent, and every path in it then means
# something in the parent's directory instead: the subproject's
# objects go into the parent's obj, its rules collide with the
# parent's rules, and the sources it names are looked for one
# directory too high.
#
# Nothing about doing it says so.  The subproject configures happily
# and builds happily; it is the parent that stops working, and it
# stops working the next time somebody builds it.
mkdir -p src sub/src

cat >Configfile <<EOF
LANGUAGES   += c
SUBPROJECTS += sub

BINARIES    += top
SOURCES     += top.c
EOF

cat >src/top.c <<'EOF'
int main(void) { return 0; }
EOF

cat >sub/Configfile <<EOF
LANGUAGES += c

BINARIES  += subbin
SOURCES   += subbin.c
EOF

cat >sub/src/subbin.c <<'EOF'
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
./bin/top
./sub/bin/subbin

##############################################################################
# Configuring from inside it                                                 #
##############################################################################
if (cd sub && $PTEST_BINARY $PCONFIGURE_ARGS) > inside.out 2>&1
then
    exit 1
fi
cat inside.out

# The variable is named, because it is the evidence: it is the one
# thing in the file that says a parent is setting it, and somebody who
# has never seen it before can go and look.
grep -q "'pconfigure_subdir_sub ?='" inside.out

# What would go wrong, since "no" on its own leaves whoever typed it
# with no idea whether this is a rule or a real problem.
grep -q "build this project into its own directories" inside.out

# Both ways out.  Running it from the top is the answer nearly every
# time, and deleting the Makefile is the answer for a tree that used
# to be a subproject and isn't one now -- which is a case that would
# otherwise be stuck here forever.
grep -q "run pconfigure at the top of the tree instead" inside.out
grep -q "delete this Makefile" inside.out

# It stopped before writing anything.  A Makefile half replaced is
# worse than the one that was there, and the one that was there is
# still exactly right.
grep -q "^pconfigure_subdir_sub ?=\$" sub/Makefile

##############################################################################
# ... and the build it was going to break                                    #
##############################################################################
# The whole point of refusing is here: the tree is still the tree it
# was, from the top and from inside the subproject both.
make $MAKE_ARGS
./bin/top
./sub/bin/subbin

(cd sub && make $MAKE_ARGS && ./bin/subbin)

##############################################################################
# A project that isn't a subproject any more                                 #
##############################################################################
# Deleting the Makefile is what the message says to do, so it has to
# be what actually works.  Done last, because it leaves behind exactly
# the Makefile the rest of this test is about not having.
rm -f sub/Makefile
(cd sub && $PTEST_BINARY $PCONFIGURE_ARGS)

if grep -q "^pconfigure_subdir_sub ?=\$" sub/Makefile
then
    exit 1
fi

(cd sub && make $MAKE_ARGS && ./bin/subbin)

exit 0
