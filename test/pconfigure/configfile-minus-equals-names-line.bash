#include "harness_start.bash"

# "-=" is the operator somebody will reach for to take back something
# an earlier line added, and no command implements it.  Whatever
# pconfigure does with one, it has to say where: a refusal that doesn't
# name the line leaves its author wondering which of their removals it
# was.  And the advice can't be the usual swap to the right operator,
# which would turn the removal into an addition.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += main
COMPILEOPTS += -DKEEP
COMPILEOPTS -= -DKEEP
SOURCES     += main.c
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    exit 1
fi
cat out
grep -q -- "-=" out
grep -q "Configfile:5" out
grep -q "delete the line that added it" out
test ! -e Makefile
