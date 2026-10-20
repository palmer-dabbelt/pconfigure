#include "harness_start.bash"
#include "real_bootstrap.bash"

# A fresh checkout of a tree that BOOTSTRAPs the real pconfigure, with
# AUTORECONFIGURE on, builds in one make.
#
# It did not.  The reconfigure rule named the vendored tool by the
# relative path its own subproject builds it under, and make, which
# remakes the makefiles it includes before it reads them, found that
# rule and went to build the tool right then -- before it had read the
# pdeps fragments that say which objects the tool and its libraries are
# linked out of.  On a fresh checkout none of those fragments exist
# yet, so all four libraries were linked out of nothing.  pdeps, linked
# against them, then died in the loader the first time it ran, so the
# fragments that would have put the libraries right could never be
# written, and the tree stayed that way through every make after.
# The stand-in tool the other bootstrap tests use is a shell script
# with no objects and no fragments, which is why none of them noticed.

real_bootstrap_tree

real_bootstrap_make first.out
test "$(./bin/hello)" = "hello"
real_bootstrap_tools_load

# The spelling that makes it work, asserted as text, because it is the
# kind of thing that looks like it wants tidying.  Absolute, which is a
# prerequisite make has no rule for and so only ever compares, and
# inside a "$(wildcard)" so a "make clean" that took the tool away is
# not "No rule to make target".  "[^ )]*" keeps the leading "/" and the
# tool in the same term, the way autoreconfigure-pdeps-rebuilt does for
# pdeps.  And the relative spelling, asserted absent, since a line with
# both would pass the first check and still break.
grep -q '^Makefile\.pconfigure: \$(wildcard /[^ )]*/tools/pconfigure/bin/pconfigure)$' \
    Makefile.pconfigure
if grep -qE '^Makefile\.pconfigure:(.* )?tools/pconfigure/bin/pconfigure( |$)' \
    Makefile.pconfigure
then
    exit 1
fi

# And it settles.  The build linked its own copy of the tool after the
# configure that wrote this Makefile ran, so one reconfigure on the
# next make is the rule doing its job; a second would be a loop, and a
# third make that does anything at all is a tree that never converges.
real_bootstrap_make second.out
real_bootstrap_tools_load
test "$(grep -c "^PCONFIGURE$" second.out)" -le 1

real_bootstrap_make settled.out
grep -q "Nothing to be done" settled.out

exit 0
