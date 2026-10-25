#include "harness_start.bash"

# "--verbose" asks for a Makefile that prints each command it runs.
# Under AUTORECONFIGURE a Configfile edit re-runs pconfigure from
# inside make, and that run has to write the Makefile that was asked
# for: one that goes quiet half way through somebody's debugging
# session, because they touched a Configfile, is the sort of change a
# person only notices once they have lost the log they wanted.

export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src

cat >Configfile <<'EOF'
AUTORECONFIGURE  = true
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
EOF

echo 'int main(void) { return 0; }' > src/main.c

$PTEST_BINARY $PCONFIGURE_ARGS --verbose
make $MAKE_ARGS > first.log 2>&1
cat first.log
grep -q -- '-oobj/bin/main/' first.log

sleep 1
echo "# a comment" >> Configfile
touch src/main.c

make $MAKE_ARGS > second.log 2>&1
cat second.log
grep -q "^PCONFIGURE$" second.log

# The relink after the touched source, which a verbose Makefile spells
# out in full and a quiet one calls "LD".
grep -q -- '-oobj/bin/main/' second.log

exit 0
