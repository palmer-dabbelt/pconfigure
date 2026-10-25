#include "harness_start.bash"

# The "#else" half of the same habit: "#else # no extras".  pbashc
# compiles it, so pconfigure's scan has to accept it too, and has to
# flip which branch is being read just as a bare "#else" would.
#
# Each branch is an include, so which of them ended up in the
# dependencies says whether the "#else" was taken for one: the first
# branch isn't taken, so only the second one's file belongs there.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES   += bash

BINARIES    += tool
SOURCES     += tool.bash
EOF

cat >src/tool.bash <<'EOF'
#ifdef WITH_EXTRAS
#include "extras.bash"
#else # no extras, use the fallback
#include "fallback.bash"
#endif
echo tool
EOF

echo "echo extras" >src/extras.bash
echo "echo fallback" >src/fallback.bash

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/tool)" = "fallback
tool"
grep "^bin/tool:" Makefile | grep -q "src/fallback.bash"
if grep "^bin/tool:" Makefile | grep -q "src/extras.bash"
then
    exit 1
fi

exit 0
