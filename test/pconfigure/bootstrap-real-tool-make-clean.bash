#include "harness_start.bash"
#include "real_bootstrap.bash"

# "make clean" in a tree that BOOTSTRAPs the real pconfigure with
# AUTORECONFIGURE on, then "make", builds.
#
# It did not.  A clean deletes everything the build made, which in a
# tree like this includes the vendored pconfigure, pdeps, the libraries
# they load, and the pdeps fragments.  The generated Makefile survived
# it, so the next make went straight to rewriting the fragments, with a
# pdeps that was not there -- "No such file or directory", on every
# make until somebody reconfigured by hand.  Nothing in that Makefile
# could build pdeps first: how to link it is what the fragments say.
# The stand-in tool the cheaper bootstrap tests use has no pdeps and no
# fragments, which is why this needs the real one.

real_bootstrap_tree
real_bootstrap_clean_then_make

exit 0
