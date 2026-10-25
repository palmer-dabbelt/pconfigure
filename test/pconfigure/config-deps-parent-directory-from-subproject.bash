#include "harness_start.bash"

# A relative CONFIG_DEPS is rooted at the project whose Configfile the
# line is in, and that includes one that climbs: a subproject naming
# "../shared" means the directory beside it, which from the top of the
# tree -- where the reconfigure rule runs -- is "shared".  Written any
# other way the prerequisite either names nothing, so adding a file
# there is never noticed, or names something that is never older than
# the Makefile, so the tree reconfigures on every make.

mkdir -p src sub/src shared

cat >Configfile <<'EOF'
AUTORECONFIGURE  = true
SUBPROJECTS     += sub
LANGUAGES       += c
BINARIES        += top
SOURCES         += top.c
EOF

cat >sub/Configfile <<'EOF'
LANGUAGES       += c
BINARIES        += subbin
SOURCES         += sub.c
CONFIG_DEPS     += ../shared
EOF

echo 'int main(void) { return 0; }' > src/top.c
echo 'int main(void) { return 0; }' > sub/src/sub.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
grep '^Makefile:' Makefile
grep -q '\$(wildcard shared)' Makefile

# Neither unrooted spelling: "../shared" from the top is outside the
# tree, and "sub/../shared" is the right directory under a name the
# rest of the Makefile never uses.
if grep -qE '\$\(wildcard (sub/)?\.\./shared\)' Makefile
then
    exit 1
fi

make $MAKE_ARGS > settled.log 2>&1
cat settled.log
grep -q "Nothing to be done" settled.log

sleep 1
touch shared/new
make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
grep -q "^PCONFIGURE$" second.log

make $MAKE_ARGS > third.log 2>&1
cat third.log
grep -q "Nothing to be done" third.log

exit 0
