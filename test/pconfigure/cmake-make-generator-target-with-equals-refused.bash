#include "harness_start.bash"

# With cmake's default generator the build is a "$(MAKE) -C" into the
# build directory with each '--target' on its command line, so a
# '--target' with an '=' in it is a make variable rather than a goal.
# 'DESTDIR' is refused in every other channel that reaches the tree --
# an --env, a MAKEOPS -- and a '--target' that says the same thing is
# one more.
mkdir -p sub
echo 'project(sub NONE)' > sub/CMakeLists.txt

cat >Configfile <<'EOF2'
BUILD_SYSTEMS += cmake
SUBPROJECTS   += sub
CONFIGUREOPTS += --target DESTDIR=/tmp/elsewhere
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    cat out
    grep -n "DESTDIR=/tmp/elsewhere" Makefile || true
    exit 1
fi
cat out
grep -q "'--target DESTDIR=/tmp/elsewhere' sets 'DESTDIR'" out

# The generator that makes this a make variable may be written below
# the '--target', where nothing reading the '--target' yet knows there
# will be a make to read it.  Naming the make generator outright has to
# be refused all the same.
cat >Configfile <<'EOF2'
BUILD_SYSTEMS += cmake
SUBPROJECTS   += sub
CONFIGUREOPTS += --target DESTDIR=/tmp/elsewhere
CONFIGUREOPTS += --generator Unix Makefiles
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    cat out
    exit 1
fi
cat out
grep -q "'--target DESTDIR=/tmp/elsewhere' sets 'DESTDIR'" out

exit 0
