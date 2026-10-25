#include "harness_start.bash"

# A BOOTSTRAP tree is read as an ordinary subproject once it has been
# checked, so a vendored pconfigure checked out as "-pconfigure" has
# every path of its build start with "-pconfigure/", and the tools in
# its recipes read those as options rather than files.  The line is
# refused while configuring, the way a SUBPROJECTS naming the same
# directory is.
mkdir -p src ./-pconfigure/src

cat >./-pconfigure/Configfile <<EOF
LANGUAGES += bash
BINARIES  += pconfigure
SOURCES   += pconfigure.bash
EOF
echo 'exit 0' > ./-pconfigure/src/pconfigure.bash
printf '#!/bin/bash\nexit 0\n' > ./-pconfigure/bootstrap.sh
chmod +x ./-pconfigure/bootstrap.sh

cat >Configfile <<EOF
BOOTSTRAP  = -pconfigure

LANGUAGES += c
BINARIES  += main
SOURCES   += main.c
EOF
echo 'int main(void) { return 0; }' > src/main.c

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    cat out
    exit 1
fi
cat out
grep -qF "Configfile:1 'BOOTSTRAP = -pconfigure'" out
grep -qF "BOOTSTRAP names a directory starting with a '-'" out
test ! -e Makefile

exit 0
