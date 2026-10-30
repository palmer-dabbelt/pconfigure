#include "harness_start.bash"

# A SUBPROJECTS line added to the Configfile pulls in a project the
# running Makefile has never heard of, whose own Makefile does not
# exist yet.  The reconfigure the edit sets off writes it, make reads
# it as one of the makefiles it just remade, and the new subproject is
# built by the same plain make.

export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src sub/src

cat >Configfile <<'EOF'
AUTORECONFIGURE  = true
LANGUAGES       += c
BINARIES        += top
SOURCES         += top.c
EOF

cat >sub/Configfile <<'EOF'
LANGUAGES       += c
BINARIES        += subbin
SOURCES         += sub.c
EOF

echo 'int main(void) { return 0; }' > src/top.c
echo 'int main(void) { return 0; }' > sub/src/sub.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test ! -e sub/obj

sleep 1
{ head -n 1 Configfile; echo 'SUBPROJECTS     += sub'; tail -n +2 Configfile; } > Configfile.new && mv Configfile.new Configfile
cat Configfile

make $MAKE_ARGS > second.log 2>&1
cat second.log
grep -q "^PCONFIGURE$" second.log
test -x sub/bin/subbin

make $MAKE_ARGS > third.log 2>&1
cat third.log
# Make prints "Nothing to be done" after a reconfigure too, so settling
# means pconfigure didn't run again as well.
if grep -q "^PCONFIGURE$" third.log
then
    exit 1
fi
grep -q "Nothing to be done" third.log

exit 0
