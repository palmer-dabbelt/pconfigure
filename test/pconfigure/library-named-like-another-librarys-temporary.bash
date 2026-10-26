#include "harness_start.bash"

# A shared library goes into lib/ the way a program goes into bin/:
# copied to "$@.tmp" and renamed.  A second library whose name is the
# first one's plus ".tmp" is that temporary, so relinking the first
# took the second out of lib/ -- and out of the prefix, for an install
# that ran after the edit.  So the later of the two lines is refused.
mkdir -p src
echo 'int f(void) { return 1; }' > src/f.c
echo 'int g(void) { return 2; }' > src/g.c

cat >Configfile <<'EOF2'
LANGUAGES += c

LIBRARIES += libf.so.tmp
SOURCES   += g.c

LIBRARIES += libf.so
SOURCES   += f.c
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS >configure.out 2>&1
then
    cat configure.out
    exit 1
fi
cat configure.out

head -n1 configure.out | grep -qF "Configfile:6 'LIBRARIES += libf.so'"
grep -qF "Configfile:3 'LIBRARIES += libf.so.tmp'" configure.out
grep -qF "lib/libf.so.tmp'" configure.out

exit 0
