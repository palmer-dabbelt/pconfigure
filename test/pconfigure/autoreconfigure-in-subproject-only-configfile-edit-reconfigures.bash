#include "harness_start.bash"
#pconfigure TESTDEPS += bin/pdeps

# A subproject that writes its own AUTORECONFIGURE "still wins, the way
# it does with a PREFIX", and AUTORECONFIGURE is the promise that the
# build runs pconfigure again when a Configfile it was written out of
# changes.  Here the subproject asks for it and the project above it
# doesn't say.  Its sources are tracked by pdeps during the build, so
# half of the promise was always kept -- but the rule that watches
# Configfiles used to be written only when the top project asked, so an
# edit to the subproject's own Configfile was never noticed.  The
# opposite split, a top project that asks and a subproject that says
# false, watches the subproject's Configfile anyway.

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
BINARIES        += first
SOURCES         += first.c
EOC

echo 'int main(void) { return 0; }' > src/top.c
echo 'int main(void) { return 0; }' > sub/src/first.c
echo 'int main(void) { return 0; }' > sub/src/second.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test -x sub/bin/first

# The subproject did get what it asked for on the source side: its
# objects' dependencies come from pdeps fragments.
grep -q 'pdeps' sub/obj/Makefile.sub

sleep 1
cat >>sub/Configfile <<'EOC'
BINARIES        += second
SOURCES         += second.c
EOC

make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
grep -q "^PCONFIGURE$" second.log
test -x sub/bin/second
