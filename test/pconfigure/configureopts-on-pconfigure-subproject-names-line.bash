#include "harness_start.bash"

# A CONFIGUREOPTS can't reach a pconfigure subproject, since that tree
# is configured by its own Configfile.  The refusal has to name the
# line it is refusing: in a build of several projects "CONFIGUREOPTS
# doesn't apply" on its own would send whoever reads it grepping every
# Configfile in the tree for the option.  This one is a level down on
# purpose, where the top's Configfile has no CONFIGUREOPTS in it at
# all.
mkdir -p a/b

echo "SUBPROJECTS += a" > Configfile

cat >a/Configfile <<EOF
LANGUAGES     += c

SUBPROJECTS   += b
CONFIGUREOPTS += --enable-thing
EOF

echo "" > a/b/Configfile

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    exit 1
fi
cat out
grep -q "CONFIGUREOPTS doesn't apply to a pconfigure subproject" out
grep -q "a/Configfile:4" out

exit 0
