#include "harness_start.bash"

# A CONFIGUREOPTS written under the BUILD_SYSTEMS rather than under a
# SUBPROJECTS belongs to every tree built that way, so there is no
# project for its prefix to be resolved against until a SUBPROJECTS
# binds it -- which is a different line, further down.  The refusal
# still names the line that wrote the prefix, since that is the one to
# fix, rather than the SUBPROJECTS that happened to be read when it
# could finally be asked.
mkdir -p sub
touch sub/configure.ac

cat >Configfile <<'EOF'
BUILD_SYSTEMS += autotools
CONFIGUREOPTS += --prefix ../toolchain

SUBPROJECTS   += sub
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    exit 1
fi
cat out
grep -q "'--prefix ../toolchain' reaches outside the project" out
grep -q "Configfile:2 'CONFIGUREOPTS += --prefix ../toolchain'" out
if grep -q "Configfile:4" out
then
    exit 1
fi

exit 0
