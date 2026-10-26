#include "harness_start.bash"

# A meson '--define' is checked for an '=', but '--define =false' has
# nothing in front of it and is handed to "meson setup" as "-D=false",
# which meson refuses ("must be in OPTION=VALUE format") when the build
# runs rather than when the Configfile is read.  It is refused at the
# line, and an option named for a subproject, with a ':' in its name,
# is still taken.
mkdir -p sub
cat >sub/meson.build <<'EOF2'
project('hello', 'c')
EOF2

cat >Configfile <<'EOF2'
BUILD_SYSTEMS += meson
SUBPROJECTS   += sub
CONFIGUREOPTS += --define =false
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    cat out
    exit 1
fi
cat out
grep -q "Configfile:3" out
grep -qF "'--define =false' has no name in front of its '='" out
test ! -e Makefile

cat >Configfile <<'EOF2'
BUILD_SYSTEMS += meson
SUBPROJECTS   += sub
CONFIGUREOPTS += --define zlib:tests=false
EOF2
$PTEST_BINARY $PCONFIGURE_ARGS

exit 0
