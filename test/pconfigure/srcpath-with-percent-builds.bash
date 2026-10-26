#include "harness_start.bash"

# '%' is a pattern character to make only in a rule whose target has
# one, and pconfigure's source rules name a literal object as their
# target, so a source tree whose directory name has a '%' in it builds
# from a build directory beside it like any other.  An edited source
# recompiles, and the tree is settled afterwards: a '%' that make did
# read as a pattern would leave a rule that never matches its file.
mkdir -p 'tree%1/src' build
echo 'int main(void) { return 0; }' > 'tree%1/src/v.c'
cat >'tree%1/Configfile' <<'EOF2'
LANGUAGES += c
BINARIES  += v
SOURCES   += v.c
EOF2

cd build
$PTEST_BINARY --srcpath '../tree%1'
make
./bin/v
touch '../tree%1/src/v.c'
make > rebuild.out
cat rebuild.out
grep -q 'CC.*v\.c' rebuild.out
make -q
