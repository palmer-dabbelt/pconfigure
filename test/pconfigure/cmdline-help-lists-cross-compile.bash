#include "harness_start.bash"

# The manual says "pconfigure --help prints the same list in short
# form" as its Command-Line Options section, and that section has a
# --cross-compile.  cmdline-args.bash checks that every option --help
# lists is one pconfigure understands, which is the other direction:
# an option that works but was never added to the summary passes it.
# Somebody who wants to build for another machine asks --help how, and
# a summary without the one option for that tells them there isn't
# one.
$PTEST_BINARY --help > help.out 2>&1
cat help.out

# Listed the way the other options that take a value are, with the
# value named after it, so the line says what goes there too.
grep -qE '^  --cross-compile PREFIX( |$)' help.out
