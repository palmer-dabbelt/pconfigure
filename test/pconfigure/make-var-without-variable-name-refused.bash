#include "harness_start.bash"

# A '--make-var' is the same variable a MAKEOPS is, and goes onto the
# same sub-make command line, so '--make-var =1' is make's "empty
# variable name" on the first build.  It is refused where it was
# written, and under its own spelling rather than as the MAKEOPS it
# would have become, for both of the build systems that take one.
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
CONFIGUREOPTS += --make-var =1
EOF2

    if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
    then
        cat out
        echo "${tree%%:*} took '--make-var =1'"
        exit 1
    fi
    cat out
    grep -q "Configfile:3" out
    grep -qF "'--make-var =1' has no name in front of its '='" out
    test ! -e Makefile
done

exit 0
