#include "harness_start.bash"

# A CONFIG's two spellings, Configfiles/NAME and Configfile.NAME, both go
# on the reconfigure rule through "$(wildcard ...)", and the one that
# exists expands to its bare name on the rule line.  A ':' in NAME --
# "CONFIG += board:rev2", say -- read there by make as a second target
# separator would stop every make after the configure on "multiple
# target patterns" before it built anything.  Without AUTORECONFIGURE
# the same Configfile builds, and with it it has to build too.

mkdir -p src Configfiles

cat >Configfile <<'EOC'
AUTORECONFIGURE  = true
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
CONFIG          += board:rev2
EOC

echo 'COMPILEOPTS += -DREV=2' > 'Configfiles/board:rev2'
echo 'int main(void) { return REV - 2; }' > src/main.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS > first.log 2>&1 || { cat first.log; exit 1; }
cat first.log
./bin/main

make $MAKE_ARGS > settled.log 2>&1 || { cat settled.log; exit 1; }
cat settled.log
if grep -q PCONFIGURE settled.log
then
    exit 1
fi

# Editing the CONFIG reconfigures, the way editing any Configfile does.
sleep 1
echo 'COMPILEOPTS += -DREV=3' > 'Configfiles/board:rev2'
echo 'int main(void) { return REV - 3; }' > src/main.c
make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
grep -q PCONFIGURE second.log
./bin/main
