#include "harness_start.bash"

# A meson '--jobs' that isn't digits is refused while the Configfile is
# read.  The refusal of a MAKEOPS already points at its line;
# an option the build system itself turns down has every bit as much
# need to, since with several vendored trees the option text alone
# doesn't say which Configfile it came from.
mkdir -p sub
touch sub/meson.build

cat >Configfile <<'EOF2'
BUILD_SYSTEMS += meson

SUBPROJECTS   += sub
CONFIGUREOPTS += --jobs lots
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    exit 1
fi
cat out
grep -q "'--jobs lots' isn't a number of jobs" out
grep -q "Configfile:4" out

exit 0
