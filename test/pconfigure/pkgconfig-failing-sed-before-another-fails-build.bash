#include "harness_start.bash"

# A pkgconfig LIBRARY is built by a pipeline: the template is cat'd
# through one sed per substitution and one per COMPILEOPTS.  A shell
# pipeline's status is its last command's, so when a sed that isn't
# the last one refuses its expression it prints the complaint and
# hands the rest of the pipe nothing -- and the seds after it turn
# that nothing into an empty .pc and succeed.  The build passes, and
# the .pc it built, installed or not, describes no package at all.
mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES   += pkgconfig
LIBRARIES   += pkgconfig/x.pc
COMPILEOPTS += s/^Version: 1/Version: 2
COMPILEOPTS += s/@@NAME@@/x/
SOURCES     += x.pc
EOF2

cat >src/x.pc <<'EOF2'
prefix=@@pconfigure_prefix@@
Name: @@NAME@@
Description: x
Version: 1
EOF2

# Configure only builds the build-tree copy as a courtesy, and what it
# makes of a broken expression isn't the question here.
$PTEST_BINARY $PCONFIGURE_ARGS || true

# The first expression has no closing '/', so sed can't run it: make
# has to say so by failing, whichever position the bad sed is in.
if make $MAKE_ARGS lib/pkgconfig/x.pc > make.out 2>&1
then
    cat make.out
    ls -l lib/pkgconfig/x.pc
    echo "a sed that failed left an empty .pc and a passing build" >&2
    exit 1
fi
cat make.out

# Nor should the failed build leave a .pc behind for make to take as
# up to date next time, and the complaint has to say which Configfile
# line it came from: sed's own only counts expressions.
if test -e lib/pkgconfig/x.pc
then
    echo "a failed build left lib/pkgconfig/x.pc behind" >&2
    exit 1
fi
grep -q "Configfile:2: pkgconfig/x.pc could not be made" make.out
