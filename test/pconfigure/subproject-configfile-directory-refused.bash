#include "harness_start.bash"

# A subproject whose "Configfile" is a directory looks like a
# pconfigure project to the question "is there a Configfile here", and
# is then refused when it is read, naming the subproject's path rather
# than leaving the top to be blamed or reading the tree as empty.
mkdir -p sub/Configfile

cat >Configfile <<'EOF'
SUBPROJECTS += sub
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    cat out
    exit 1
fi
cat out
grep -q "^sub/Configfile$" out
grep -q "this Configfile is a directory" out
test ! -e Makefile

exit 0
