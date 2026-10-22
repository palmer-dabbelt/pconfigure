#include "harness_start.bash"

# A BOOTSTRAP is documented as a SUBPROJECTS plus two things, and a
# SUBPROJECTS inside an object directory is refused because "make
# distclean" is an "rm -rf" of that directory: a checkout in there is
# one distclean away from being gone.  The vendored pconfigure a
# project bootstraps from is the last tree anybody wants that to
# happen to, since without it the next "make" has nothing to build a
# pconfigure with -- but BOOTSTRAP does not ask.
mkdir -p src obj/pconfigure/src

cat >obj/pconfigure/Configfile <<EOF
LANGUAGES += bash
BINARIES  += pconfigure
SOURCES   += pconfigure.bash
EOF
echo 'exit 0' > obj/pconfigure/src/pconfigure.bash
printf '#!/bin/bash\nexit 0\n' > obj/pconfigure/bootstrap.sh
chmod +x obj/pconfigure/bootstrap.sh

cat >Configfile <<EOF
BOOTSTRAP  = obj/pconfigure

LANGUAGES += c
BINARIES  += main
SOURCES   += main.c
EOF
echo 'int main(void) { return 0; }' > src/main.c

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    cat out
    # What accepting it costs: the vendored tree is removed with the
    # object directory.
    make $MAKE_ARGS -f Makefile.pconfigure distclean || true
    ls obj/pconfigure || true
    exit 1
fi
cat out
grep -q "BOOTSTRAP can't name a directory inside an object directory" out
grep -q "Configfile:1" out
test ! -e Makefile
test ! -e Makefile.pconfigure

exit 0
