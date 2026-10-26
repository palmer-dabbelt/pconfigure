#include "harness_start.bash"

# pbashc writes a script to "<output>.tmp" and renames it into place,
# and the install recipe copies through "$@.tmp" in the prefix the same
# way.  A script named "run.tmp" beside one named "run" is that
# temporary: building "run" wrote over "run.tmp" and renamed it away,
# so a fresh "make" finished without one of the two scripts it had
# just reported building.
#
# Written the other way round from the compiled-program case, with the
# output whose temporary is taken first: the later line is refused
# either way, here the one that would be the temporary.
mkdir -p src
echo 'echo main' > src/run.bash
echo 'echo scratch' > src/scratch.bash

cat >Configfile <<'EOF2'
LANGUAGES += bash

BINARIES  += run
SOURCES   += run.bash

BINARIES  += run.tmp
SOURCES   += scratch.bash
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS >configure.out 2>&1
then
    cat configure.out
    exit 1
fi
cat configure.out

head -n1 configure.out | grep -qF "Configfile:6 'BINARIES += run.tmp'"
grep -qF "Configfile:3 'BINARIES += run'" configure.out
grep -qF "bin/run.tmp'" configure.out

exit 0
