#include "harness_start.bash"

# A '--define prefix=...' answers a question meson's build system has
# already answered, and is refused with '--prefix DIR' as the thing to
# write instead.  Like any fatal error in a Configfile it is about one
# line, and that line is the one to change, so the refusal names it.
mkdir -p sub
touch sub/meson.build

cat >Configfile <<'EOF2'
BUILD_SYSTEMS += meson
SUBPROJECTS   += sub
CONFIGUREOPTS += --define buildtype=release
CONFIGUREOPTS += --define prefix=/usr/local
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    exit 1
fi
cat out
grep -q "'--define prefix=/usr/local' sets 'prefix'" out
grep -q "write '--prefix DIR' instead" out
grep -q "Configfile:4" out

exit 0
