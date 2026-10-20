#include "harness_start.bash"
#include "real_bootstrap.bash"

# The vendored pconfigure's object directory deleted from a built tree
# -- which is what running its bootstrap.sh by hand does, since that
# starts from an empty one -- comes back on the next make.
#
# This is subproject-objdir-deleted-reconfigures with the subproject
# being the tool itself, and it is a harder case than an ordinary one
# for the same reason the other real-tool tests exist: the directory
# holds not only the Makefile the parent includes but every pdeps
# fragment and every object the tool and its libraries are linked out
# of.  The configure that puts the Makefile back has to leave a build
# that rewrites the fragments with the tools as they are, recompiles,
# and relinks the libraries out of complete object lists -- and the
# tools still load at the end of it.

real_bootstrap_tree

real_bootstrap_make first.out
real_bootstrap_make second.out
real_bootstrap_make settled.out
grep -q "Nothing to be done" settled.out

rm -rf tools/pconfigure/obj

real_bootstrap_make recovered.out
grep -q "^PCONFIGURE$" recovered.out
test "$(./bin/hello)" = "hello"
real_bootstrap_tools_load

# Once more for the relink that happened in the build, and then nothing.
real_bootstrap_make after.out
real_bootstrap_tools_load
real_bootstrap_make settled-again.out
grep -q "Nothing to be done" settled-again.out

exit 0
