#include "harness_start.bash"

# A generator other than make runs its build through
# "cmake --build --target", which reads what follows as the name of a
# target and nothing else: there is no command line on which an '='
# turns it into a variable.  So the refusal a make generator's
# '--target DESTDIR=...' gets is a refusal of make's reading of the
# word, and it isn't owed here -- the word reaches cmake, quoted, as
# the target name it was written as.
mkdir -p sub
echo 'project(sub NONE)' > sub/CMakeLists.txt

cat >Configfile <<'EOF2'
BUILD_SYSTEMS += cmake
SUBPROJECTS   += sub
CONFIGUREOPTS += --target DESTDIR=/tmp/elsewhere
CONFIGUREOPTS += --generator Ninja
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

grep -q -- "--target 'DESTDIR=/tmp/elsewhere'" Makefile

# And not as a word on any make's command line, which is the thing the
# make generator's refusal is about.
if grep -q "\$(MAKE).*DESTDIR=/tmp/elsewhere" Makefile
then
    exit 1
fi

exit 0
