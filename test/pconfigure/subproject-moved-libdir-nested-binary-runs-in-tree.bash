#include "harness_start.bash"

# A binary one directory down in bin/ ("tools/main") linking a library
# that a subproject builds into a LIBDIR of its own ("libs").  The
# in-tree binary has to find the library at run time from where it
# sits, so its run-time search path climbs two directories and then
# goes into the subproject's own library directory -- not the top's
# "lib", and not one directory up.  Running it is the check that
# matters; the RUNPATH is read back as well so that a failure says
# which part of the path went wrong.
mkdir -p src sub/src

cat >Configfile <<'EOF2'
SUBPROJECTS += sub

LANGUAGES   += c
BINARIES    += tools/main
LINKOPTS    += -Lsub/libs
LINKOPTS    += -lsub
SOURCES     += main.c
EOF2

cat >sub/Configfile <<'EOF2'
LANGUAGES += c
LIBDIR     = libs
LIBRARIES += libsub.so
SOURCES   += sub.c
EOF2

echo 'int sub(void) { return 3; }' > sub/src/sub.c
echo 'int sub(void); int main(void) { return sub() - 3; }' > src/main.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS -j2

test -f sub/libs/libsub.so
test ! -e sub/lib
./bin/tools/main

# From somewhere else too, since a search path that happened to be
# relative to the current directory would pass from here and nowhere
# else.
(cd / && $tempdir/bin/tools/main)

readelf -d bin/tools/main > dyn.out
cat dyn.out
grep -q 'ORIGIN/\.\./\.\./sub/libs' dyn.out

exit 0
