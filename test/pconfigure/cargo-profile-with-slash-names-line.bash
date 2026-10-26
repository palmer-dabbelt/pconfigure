#include "harness_start.bash"

# A cargo '--profile' with a '/' in it is a directory name cargo would
# never build into, and is refused with the spelling it wanted.  The
# refusal belongs to a Configfile line like every other fatal error in
# a Configfile, so it has to say which one.
mkdir -p crate
cat >crate/Cargo.toml <<'EOF2'
[package]
name = "crate"
version = "0.1.0"
EOF2

cat >Configfile <<'EOF2'
BUILD_SYSTEMS += cargo

SUBPROJECTS   += crate
CONFIGUREOPTS += --profile release/fast
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    exit 1
fi
cat out
grep -q "'--profile release/fast' isn't a profile name" out
grep -q "Configfile:4" out

exit 0
