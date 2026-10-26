#include "harness_start.bash"

# A '--target' for a tree run by make goes onto the sub-make's command
# line, where a word with an '=' in it is a variable rather than a
# goal.  '--target =modules' is that with no name, and make stops on
# "empty variable name" when the tree is built.  kbuild's '--target'
# already asks whether such a word names where the tree installs, but
# an empty name is no destination and got past that.  Both build
# systems that take one refuse it at the line.
mkdir -p a k
cat >a/configure <<'EOF2'
#!/bin/sh
exit 0
EOF2
chmod +x a/configure
cat >k/Kconfig <<'EOF2'
config X
	bool "x"
EOF2
echo "all:" > k/Makefile

for tree in autotools:a kconfig:k
do
    cat >Configfile <<EOF2
BUILD_SYSTEMS += ${tree%%:*}
SUBPROJECTS   += ${tree##*:}
CONFIGUREOPTS += --target =modules
EOF2

    if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
    then
        cat out
        echo "${tree%%:*} took '--target =modules'"
        exit 1
    fi
    cat out
    grep -q "Configfile:3" out
    grep -qF "'--target =modules' has no name in front of its '='" out
    test ! -e Makefile
done

exit 0
