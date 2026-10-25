#include "harness_start.bash"

# SRCPATH can be written in a Configfile as well as given as
# "--srcpath", and a Configfile's is no less likely to be misspelled.
# Read from a directory that isn't there, the rest of the Configfile
# names sources nobody will find until make goes looking for them, so
# the refusal comes from pconfigure and points at the line that said
# it rather than at the first source that went missing.
cat >Configfile <<'EOF2'
SRCPATH          = no-such-tree

LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    exit 1
fi
cat out
test ! -e Makefile
grep -q "Configfile:1 'SRCPATH = no-such-tree'" out
grep -q "no-such-tree', which doesn't exist" out
