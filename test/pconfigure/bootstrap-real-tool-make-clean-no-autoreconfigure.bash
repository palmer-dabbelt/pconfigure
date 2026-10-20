#include "harness_start.bash"
#include "real_bootstrap.bash"

# bootstrap-real-tool-make-clean, without AUTORECONFIGURE.
#
# There are no pdeps fragments in this mode -- dependencies are worked
# out at configure time and written into the Makefile -- so it does not
# break the way that test's tree did.  It broke anyway: the vendored
# library includes a header the vendored build generates with phc, and
# the clean took both the header and phc, so the Makefile left behind
# could not make the header again (and under -j, sometimes compiled the
# library before trying, and failed on that instead).  Same make after
# the same clean, failing on every run until somebody reconfigured by
# hand, and found only by asking whether the fix for the other mode
# needed to be limited to it.

real_bootstrap_tree no-autoreconfigure
real_bootstrap_clean_then_make

exit 0
