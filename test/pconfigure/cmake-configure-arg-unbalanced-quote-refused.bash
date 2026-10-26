#include "harness_start.bash"

# A cmake '--configure-arg' is pasted into the recipe as written, so
# somebody can write the quotes themselves.  One that opens a quote and
# never closes it makes every "make" stop with the shell's "unexpected
# EOF while looking for matching", from a recipe line nobody wrote --
# so it has to be refused where it was written, naming the line.
mkdir -p sub
echo 'project(sub NONE)' > sub/CMakeLists.txt

cat >Configfile <<'EOF2'
BUILD_SYSTEMS += cmake
SUBPROJECTS   += sub
CONFIGUREOPTS += --configure-arg '-DGREETING=hello world
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    cat out
    grep -n "GREETING" Makefile || true
    exit 1
fi
cat out
grep -q "Configfile:3" out
grep -q "single quote that never closes" out

exit 0
