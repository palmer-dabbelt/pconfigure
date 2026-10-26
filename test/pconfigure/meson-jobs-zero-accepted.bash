#include "harness_start.bash"

# cargo and cmake refuse "--jobs 0", but a meson subproject's "--jobs"
# is handed to ninja as "-j", and ninja reads "-j 0" as "as many as
# there is work for".  That is a thing somebody might mean, so the
# zero that is refused for the other two is passed through here, and
# this pins it so that a refusal copied across from them doesn't take
# it away.
mkdir -p sub
cat >sub/meson.build <<'EOF2'
project('hello', 'c')
EOF2

cat >Configfile <<'EOF2'
BUILD_SYSTEMS += meson

SUBPROJECTS   += sub
CONFIGUREOPTS += --jobs 0
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
grep -q -- "ninja -C .* -j 0" Makefile
