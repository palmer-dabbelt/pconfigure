#include "harness_start.bash"

# A bootstrap is what gets run when a build wants a pconfigure and
# there is none -- and the usual reason there is none is that a parent
# project has just been told to make one out of a tree it vendors.
#
# A tree that has been through an older pconfigure has a Makefile
# sitting at the top of it that the parent wrote, from back when a
# parent wrote that file rather than one in the object directory.  It
# is written to be included from above, and means something else
# entirely from in here.
#
# So a bootstrap has to clear it away before it starts, which is a
# thing it has to keep doing for as long as such trees exist.  The
# detail below is the one that file is recognized by, and a bootstrap
# that tripped over it would make "make clean" followed by "make" at
# the top of such a project stop on a file nobody was asking about.
#
# This runs the real bootstrap, out of tree, because the refusal is
# the real pconfigure's and a stand-in for it would only be testing
# the stand-in.

test "$PTEST_SRCDIR" != ""
test -x "$PTEST_SRCDIR/bootstrap.sh"

mkdir -p build
cd build

# What a parent leaves behind, in the one detail the refusal keys on.
cat > Makefile <<'EOF'
pconfigure_subdir_src_pconfigure ?=

all:
	@echo "included from above"
EOF

"$PTEST_SRCDIR/bootstrap.sh" "$PTEST_SRCDIR/" > log 2>&1 || {
    cat log
    exit 1
}
cat log

# It got far enough to have built everything, rather than far enough
# to have printed the refusal.
test -x bin/pconfigure
test -x bin/pdeps
test -x bin/psubdeps

# And what it left is a Makefile for a tree standing on its own: no
# variable saying where a parent thinks this project is, because from
# in here there is nobody to ask.  A parent that configures this tree
# later leaves this file alone and writes its own beside the objects.
if grep -q "pconfigure_subdir" Makefile
then
    exit 1
fi

exit 0
