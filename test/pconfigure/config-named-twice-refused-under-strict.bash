#include "harness_start.bash"

# A CONFIG that names a file already read is a warning tagged with
# v0.13 (config-named-twice-warns-naming-both-lines.bash), so a project
# that asked for that much strictness is refused at the second CONFIG
# line rather than at a target the repeat happens to declare twice --
# which used to be all that was said, pointing at a line in the CONFIG'd
# file as a duplicate of itself.
mkdir -p src Configfiles
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfiles/extra <<'EOF2'
BINARIES    += main
SOURCES     += main.c
EOF2

cat >Configfile <<'EOF2'
STRICT       = v0.13
LANGUAGES   += c
CONFIG      += extra
CONFIG      += extra
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    echo "a CONFIG named twice was accepted under STRICT" >&2
    exit 1
fi
cat out
grep -q "Configfile:4 'CONFIG += extra'" out
grep -q "error: .*Configfiles/extra.* was already read" out
grep -q "Configfile:3 'CONFIG += extra'" out
grep -q "Configfile:1" out
test ! -e Makefile
