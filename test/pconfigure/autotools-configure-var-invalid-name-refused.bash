#include "harness_start.bash"

# A '--configure-var' is handed to a generated configure as NAME=VALUE,
# and a generated configure refuses one whose name isn't a shell name
# ("invalid variable name") -- at build time, from inside a recipe.
# That rule is autoconf's and it is clear, and it is the one an '--env'
# is already held to, so a '--configure-var' with no name, with one
# that starts with a digit or with one that has a '-' in it is refused
# where it was written.  A name with a digit after the first character
# is a shell name, and is still taken.
mkdir -p sub
cat >sub/configure <<'EOF2'
#!/bin/sh
exit 0
EOF2
chmod +x sub/configure

for var in '=yes' '1CC=gcc' 'MY-CC=gcc'
do
    cat >Configfile <<EOF2
BUILD_SYSTEMS += autotools
SUBPROJECTS   += sub
CONFIGUREOPTS += --configure-var $var
EOF2

    if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
    then
        cat out
        echo "'--configure-var $var' was accepted"
        exit 1
    fi
    cat out
    grep -q "Configfile:3" out
    grep -qF "'--configure-var $var'" out
    grep -qF "YACC=/opt/bin/bison" out
    test ! -e Makefile
done

cat >Configfile <<'EOF2'
BUILD_SYSTEMS += autotools
SUBPROJECTS   += sub
CONFIGUREOPTS += --configure-var CC_1=gcc
EOF2
$PTEST_BINARY $PCONFIGURE_ARGS

exit 0
