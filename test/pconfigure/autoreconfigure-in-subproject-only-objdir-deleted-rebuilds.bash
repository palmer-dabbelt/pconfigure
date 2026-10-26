#include "harness_start.bash"
#pconfigure TESTDEPS += bin/pdeps

# Under AUTORECONFIGURE a subproject's deleted object directory comes
# back on the next make: the Makefile its parent includes is put back by
# a rule that runs the configure (see subproject-objdir-deleted-reconfigures).
# A subproject that asks for AUTORECONFIGURE itself, under a parent that
# doesn't say, gets pdeps for its sources and has to get that rule too:
# without it, deleting its object directory leaves every make stopping
# on "No rule to make target" for a file only a configure writes.

mkdir -p src sub/src

cat >Configfile <<'EOC'
SUBPROJECTS     += sub
LANGUAGES       += c
BINARIES        += top
SOURCES         += top.c
EOC

cat >sub/Configfile <<'EOC'
AUTORECONFIGURE  = true
LANGUAGES       += c
BINARIES        += subbin
SOURCES         += subbin.c
EOC

echo 'int main(void) { return 0; }' > src/top.c
echo 'int main(void) { return 0; }' > sub/src/subbin.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test -x sub/bin/subbin

rm -rf sub/obj sub/bin

make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
test -x sub/bin/subbin
