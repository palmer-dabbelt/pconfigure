#include "harness_start.bash"

# A MAKEOPS is checked for an '=', since without one make would read
# it as a goal.  With nothing in front of the '=' it is neither a goal
# nor a variable: make stops on "empty variable name" the first time
# the tree is built, from inside a recipe, with nothing to say which
# Configfile line it came from.  The same goes for ':=', which is one
# of make's assignment operators and not a name.  Both are refused
# where they were written, the way an '--env' with no name already is,
# and a name in front of a ':=' is still a name.
mkdir -p k
cat >k/Kconfig <<'EOF2'
config X
	bool "x"
EOF2
echo "all:" > k/Makefile

for var in '=arm64' ':=arm64'
do
    cat >Configfile <<EOF2
BUILD_SYSTEMS += kconfig
SUBPROJECTS   += k
MAKEOPS       += $var
EOF2

    if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
    then
        cat out
        echo "'MAKEOPS += $var' was accepted"
        exit 1
    fi
    cat out
    grep -q "Configfile:3" out
    grep -qF "'MAKEOPS += $var' has no name in front of its '='" out
    grep -qF "it should look like 'MAKEOPS += ARCH=arm64'" out
done

cat >Configfile <<'EOF2'
BUILD_SYSTEMS += kconfig
SUBPROJECTS   += k
MAKEOPS       += ARCH:=arm64
EOF2
$PTEST_BINARY $PCONFIGURE_ARGS

exit 0
