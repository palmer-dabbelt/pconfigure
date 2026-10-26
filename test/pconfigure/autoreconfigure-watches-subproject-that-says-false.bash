#include "harness_start.bash"

# A top project under AUTORECONFIGURE and a subproject that turns it off
# for itself.  The subproject's "false" decides who works out its
# sources' dependencies -- pconfigure, once, so its Makefile carries no
# pdeps fragments -- but its Configfile is still one the top's Makefile
# was written out of, and the top asked for those to be watched.
# Editing it reconfigures from the top.

mkdir -p src sub/src

cat >Configfile <<'EOC'
AUTORECONFIGURE  = true
SUBPROJECTS     += sub
LANGUAGES       += c
BINARIES        += top
SOURCES         += top.c
EOC

cat >sub/Configfile <<'EOC'
AUTORECONFIGURE  = false
LANGUAGES       += c
BINARIES        += first
SOURCES         += first.c
EOC

echo 'int main(void) { return 0; }' > src/top.c
echo 'int main(void) { return 0; }' > sub/src/first.c
echo 'int main(void) { return 0; }' > sub/src/second.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
if grep -q 'pdeps' sub/obj/Makefile.sub
then
    exit 1
fi
grep -q 'pdeps' Makefile

sleep 1
cat >>sub/Configfile <<'EOC'
BINARIES        += second
SOURCES         += second.c
EOC

make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
grep -q "^PCONFIGURE$" second.log
test -x sub/bin/second

# The reconfigure rewrote the subproject's Makefile, and its "false"
# still held: the new binary's source got no pdeps fragment either.
grep -q 'second' sub/obj/Makefile.sub
if grep -q 'pdeps' sub/obj/Makefile.sub
then
    exit 1
fi

make $MAKE_ARGS > third.log 2>&1 || { cat third.log; exit 1; }
cat third.log
if grep -q "^PCONFIGURE$" third.log
then
    exit 1
fi
