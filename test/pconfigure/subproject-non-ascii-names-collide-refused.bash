#include "harness_start.bash"

# Every project's Makefile finds its directory through a variable
# spelled from the directory's name, with anything that isn't a letter
# or digit squeezed to an underscore.  "café" and "cafè" differ only in
# bytes that get squeezed, so they would share one variable and each
# build in the other's directory.  The pair is refused, naming both
# lines, before any Makefile is written.
for d in café cafè
do
    mkdir -p $d/src
    echo 'int main(void) { return 0; }' > $d/src/m.c
done

cat >café/Configfile <<'EOF'
LANGUAGES += c
BINARIES  += one
SOURCES   += m.c
EOF

cat >cafè/Configfile <<'EOF'
LANGUAGES += c
BINARIES  += two
SOURCES   += m.c
EOF

cat >Configfile <<'EOF'
SUBPROJECTS += café
SUBPROJECTS += cafè
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    cat out
    exit 1
fi
cat out
grep -q "Configfile:2 'SUBPROJECTS += cafè'" out
grep -q "Configfile:1 'SUBPROJECTS += café'" out
test ! -e Makefile

# One of the two on its own is fine.
cat >Configfile <<'EOF'
SUBPROJECTS += café
EOF
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test -x café/bin/one

exit 0
