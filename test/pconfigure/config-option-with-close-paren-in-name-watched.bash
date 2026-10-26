#include "harness_start.bash"

# The command-line spelling of a ')' in a watched Configfile: run with
# --config 'x)y', pconfigure reads Configfile.x)y and the Makefile
# watches it inside a "$(wildcard ...)" that the ')' closes early,
# leaving 'y)' as a prerequisite nothing makes.  The build stops on
# every make, though the configure itself went fine.

mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c
echo '# extra' > 'Configfile.x)y'
cat >Configfile <<'EOC'
AUTORECONFIGURE  = true
# Nothing else here is watched.
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
EOC

$PTEST_BINARY $PCONFIGURE_ARGS --config 'x)y'
make $MAKE_ARGS

# Unchanged, it reconfigures nothing.
make $MAKE_ARGS > first.log 2>&1 || { cat first.log; exit 1; }
cat first.log
if grep -q PCONFIGURE first.log
then
    exit 1
fi

sleep 1
echo '# 2' >> 'Configfile.x)y'
make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
grep -q PCONFIGURE second.log
