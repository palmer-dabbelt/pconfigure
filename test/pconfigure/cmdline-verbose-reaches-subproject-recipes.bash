#include "harness_start.bash"

# --verbose sets VERBOSE for the whole project before any Configfile is
# read, and a subproject is part of the whole project: its recipes
# echo the commands they run just as the top project's do, rather than
# only the short labels.
mkdir -p lib/src
echo 'int main(void) { return 0; }' > lib/src/hello.c
cat >lib/Configfile <<'EOF2'
LANGUAGES += c
BINARIES  += hello
SOURCES   += hello.c
EOF2
echo 'SUBPROJECTS += lib' > Configfile

# Without --verbose the subproject prints only its labels, so the
# commands looked for below are something --verbose added rather than
# something always there.
$PTEST_BINARY
make > quiet.out 2>&1
cat quiet.out
grep -q 'CC.*hello\.c' quiet.out
if grep -q -- '-c lib/src/hello\.c\|cp --reflink=auto' quiet.out
then
    exit 1
fi

$PTEST_BINARY --verbose
make clean
make > loud.out 2>&1
cat loud.out
grep -q -- '-c lib/src/hello\.c' loud.out
grep -q 'cp --reflink=auto .* lib/bin/hello\.tmp' loud.out
./lib/bin/hello
