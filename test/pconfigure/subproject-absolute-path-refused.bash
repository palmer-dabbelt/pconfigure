#include "harness_start.bash"

# An absolute SUBPROJECTS names one directory however the line is
# read, which is exactly what stops it being a directory of this
# project's: the checkout moves between one machine and the next and
# the path doesn't.  SUBPROJECTS is documented as relative to the
# Configfile that names it, and every other command that names a path
# already refuses an absolute one.
#
# Pointing it at a directory that really is inside the project is the
# case that slipped through, since the symlink check only asks whether
# the resolved directory leaves the tree -- and what came out was a
# Makefile with this machine's absolute path baked into its include
# line and its variable names.
mkdir -p src a/src

cat >Configfile <<EOF2
SUBPROJECTS += $(pwd)/a

LANGUAGES   += c
BINARIES    += top
SOURCES     += top.c
EOF2

cat >a/Configfile <<EOF2
LANGUAGES   += c
LIBRARIES   += liba.so
SOURCES     += a.c
EOF2

echo 'int main(void) { return 0; }' > src/top.c
echo 'int a(void) { return 0; }' > a/src/a.c

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    cat out
    cat Makefile
    exit 1
fi
cat out
grep -q "SUBPROJECTS can't name an absolute path" out
grep -q "'./Configfile:1 'SUBPROJECTS += $(pwd)/a''" out
grep -q "SUBPROJECTS += vendor/sub" out
test ! -e Makefile

exit 0
