#include "harness_start.bash"

# A CONFIG's file is watched under AUTORECONFIGURE through the same
# "$(wildcard ...)" as a CONFIG_DEPS, so a ')' in its name closes the
# call early: 'Configfile.more)x' leaves 'x)' as a prerequisite of the
# Makefile that no rule makes, and every make stops there.  pconfigure
# found and read the file without trouble, so it is the watching alone
# that breaks.

mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c
echo '# more' > 'Configfile.more)x'
cat >Configfile <<'EOC'
AUTORECONFIGURE  = true
CONFIG          += more)x
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
EOC

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

# Unchanged, it reconfigures nothing.
make $MAKE_ARGS > first.log 2>&1 || { cat first.log; exit 1; }
cat first.log
if grep -q PCONFIGURE first.log
then
    exit 1
fi

sleep 1
echo '# 2' >> 'Configfile.more)x'
make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
grep -q PCONFIGURE second.log
