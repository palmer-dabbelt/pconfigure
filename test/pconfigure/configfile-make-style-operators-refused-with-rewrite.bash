#include "harness_start.bash"

# Somebody who writes Makefiles will reach for make's other assignment
# operators -- ':=', '?=' -- and a typo gives '=='.  None of them is a
# Configfile operator, and each is refused naming its line with the
# line written back the right way, so the fix can be pasted over it.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

for op in ':=' '?=' '=='
do
    cat >Configfile <<EOF
LANGUAGES   += c
BINARIES    += main
SOURCES     $op main.c
EOF

    if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
    then
        cat out
        exit 1
    fi
    cat out
    grep -q "Configfile:3" out
    grep -qF "'$op' is not an operator" out
    grep -qF "SOURCES += main.c" out
    test ! -e Makefile

    cat >Configfile <<EOF
PREFIX      $op /opt/thing
LANGUAGES   += c
EOF

    if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
    then
        cat out
        exit 1
    fi
    cat out
    grep -q "Configfile:1" out
    grep -qF "PREFIX = /opt/thing" out
    test ! -e Makefile
done
