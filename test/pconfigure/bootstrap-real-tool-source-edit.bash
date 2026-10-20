#include "harness_start.bash"
#include "real_bootstrap.bash"

# What the reconfigure-on-tool rule is for, with the real tool rather
# than bootstrap-tool-source-change-reconfigures-once's stand-in: an
# edit to a source the vendored pconfigure links -- here one of its
# libraries, so the relink goes through the shared objects the tools
# load -- rebuilds the tool out of a complete object list, the tool
# still runs, the tree is reconfigured with it, and then it settles.
#
# The edit is to a library rather than to a binary's own source because
# that is the shape that broke: a library relinked out of the wrong
# object list does not fail to link, it fails later, in the loader, the
# first time anything that uses it runs.

real_bootstrap_tree

real_bootstrap_make first.out
real_bootstrap_make second.out
real_bootstrap_make settled.out
grep -q "Nothing to be done" settled.out

sleep 2
echo "// edited" >> tools/pconfigure/src/libmakefile/target.c++

real_bootstrap_make edited.out
grep -q "target\.c++" edited.out
real_bootstrap_tools_load
test "$(./bin/hello)" = "hello"

# The relink happens in the build, after the makefiles were read, so the
# reconfigure it calls for is the next make's -- once, and then nothing.
real_bootstrap_make reconfigured.out
test "$(grep -c "^PCONFIGURE$" reconfigured.out)" -eq 1
real_bootstrap_tools_load

real_bootstrap_make settled-again.out
grep -q "Nothing to be done" settled-again.out

exit 0
