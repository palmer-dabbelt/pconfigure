#include "harness_start.bash"

# SUBPROJECTS asks a second time of where a symlink actually leads,
# because "rm -rf vendor/pconfigure/obj" walks through a symlinked
# "vendor/pconfigure" -- and a tree that is really somewhere else
# is a tree whose build output, and whose distclean, land out there.
# A BOOTSTRAP is read as a subproject in every other respect, so the
# same link has to get the same refusal; and the committed Makefile
# naming a link that only resolves on this machine is the mistake the
# "../" refusal exists to stop, arrived at by a different spelling.
mkdir -p outside/pconfigure/src proj/src proj/vendor

cat >outside/pconfigure/Configfile <<EOF
LANGUAGES += bash
BINARIES  += pconfigure
SOURCES   += pconfigure.bash
EOF
echo 'exit 0' > outside/pconfigure/src/pconfigure.bash
printf '#!/bin/bash\nexit 0\n' > outside/pconfigure/bootstrap.sh
chmod +x outside/pconfigure/bootstrap.sh

ln -s ../../outside/pconfigure proj/vendor/pconfigure

cat >proj/Configfile <<EOF
BOOTSTRAP  = vendor/pconfigure

LANGUAGES += c
BINARIES  += main
SOURCES   += main.c
EOF
echo 'int main(void) { return 0; }' > proj/src/main.c

# The same link under a SUBPROJECTS is refused, which is the answer
# being asked for.
mkdir -p sub/vendor
ln -s ../../outside/pconfigure sub/vendor/pconfigure
echo "SUBPROJECTS += vendor/pconfigure" > sub/Configfile
if (cd sub && $PTEST_BINARY $PCONFIGURE_ARGS) > sub.out 2>&1
then
    exit 1
fi
cat sub.out
grep -q "SUBPROJECTS can't reach outside the project" sub.out

if (cd proj && $PTEST_BINARY $PCONFIGURE_ARGS) > out 2>&1
then
    cat out
    ls outside/pconfigure/obj || true
    exit 1
fi
cat out
grep -q "BOOTSTRAP can't reach outside the project" out
# Refused before anything was written, so nothing out there was built
# into or set up to be distcleaned.
test ! -e proj/Makefile
test ! -e outside/pconfigure/obj
grep -q "Configfile:1" out

exit 0
