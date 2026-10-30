#include "harness_start.bash"

# A subproject removed outright: its directory deleted, and the
# SUBPROJECTS line with it.  The Makefile make reads first still
# includes the subproject's Makefile, which went with the directory, so
# make wants to put that back while it also reconfigures for the edited
# Configfile.  The configure that runs must be the one reading the edited
# Configfile -- one that went looking for the deleted directory would
# fail -- and the tree has to come out building and settled.

mkdir -p src sub/src

cat >Configfile <<'EOC'
AUTORECONFIGURE  = true
SUBPROJECTS     += sub
LANGUAGES       += c
BINARIES        += top
SOURCES         += top.c
EOC

cat >sub/Configfile <<'EOC'
LANGUAGES       += c
BINARIES        += subbin
SOURCES         += subbin.c
EOC

echo 'int main(void) { return 0; }' > src/top.c
echo 'int main(void) { return 0; }' > sub/src/subbin.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test -x sub/bin/subbin

# The top Makefile includes the subproject's before the edit, so the
# grep after it is known to be looking for something that was there.
grep -q 'Makefile\.sub' Makefile

sleep 1
rm -rf sub
sed -i.bak '/^SUBPROJECTS/d' Configfile

make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
grep -q "^PCONFIGURE$" second.log
if grep -q 'Makefile.sub' Makefile
then
    exit 1
fi
test -x bin/top
test ! -e sub

make $MAKE_ARGS > third.log 2>&1 || { cat third.log; exit 1; }
cat third.log
grep -q "Nothing to be done" third.log
