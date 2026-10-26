#include "harness_start.bash"

# A CONFIG_DEPS is watched through "$(wildcard ...)", which is a glob,
# and a glob reads a backslash as quoting the character after it.  So
# unless it is quoted, a file named 'notes\1.txt' is looked for as
# 'notes1.txt', the wildcard comes to nothing, and editing the file
# never reconfigures.

mkdir -p src

cat >Configfile <<'EOC'
AUTORECONFIGURE  = true
CONFIG_DEPS     += notes\1.txt
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
EOC

echo 'int main(void) { return 0; }' > src/main.c
echo 1 > 'notes\1.txt'

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS > first.log 2>&1 || { cat first.log; exit 1; }
cat first.log

# Unchanged, a second make settles.
make $MAKE_ARGS > settled.log 2>&1 || { cat settled.log; exit 1; }
cat settled.log
if grep -q PCONFIGURE settled.log
then
    exit 1
fi

# And an edit to the file is what the line was written for.
sleep 1
echo 2 > 'notes\1.txt'
make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
grep -q PCONFIGURE second.log
