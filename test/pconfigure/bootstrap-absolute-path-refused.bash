#include "harness_start.bash"

# The Makefile a BOOTSTRAP writes is meant to be committed, which is
# why a path climbing out of the tree is refused: it names nothing on
# anybody else's machine.  An absolute path is the same mistake
# spelled more plainly -- it names this machine's checkout, and every
# clone of the repository gets a Makefile that bootstraps from a
# directory that isn't there -- but only "../" is looked for, so it
# goes straight into PCONFIGURE_SRCPATH.
mkdir -p src vendor/pconfigure/src

cat >vendor/pconfigure/Configfile <<EOF
LANGUAGES += bash
BINARIES  += pconfigure
SOURCES   += pconfigure.bash
EOF
echo 'exit 0' > vendor/pconfigure/src/pconfigure.bash
printf '#!/bin/bash\nexit 0\n' > vendor/pconfigure/bootstrap.sh
chmod +x vendor/pconfigure/bootstrap.sh

cat >Configfile <<EOF
BOOTSTRAP  = $(pwd)/vendor/pconfigure

LANGUAGES += c
BINARIES  += main
SOURCES   += main.c
EOF
echo 'int main(void) { return 0; }' > src/main.c

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    cat out
    grep "PCONFIGURE_SRCPATH  =" Makefile || true
    exit 1
fi
cat out
grep -q "BOOTSTRAP can't be an absolute path" out
grep -q "Configfile:1" out
test ! -e Makefile

exit 0
