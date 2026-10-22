#include "harness_start.bash"

# "a-b" and "a/b" are different directories that mangle to the same
# make variable, and pconfigure refuses the pair rather than let one
# build into the other's directory.  Here the second of them is asked
# for by a subproject rather than by the top, so the refusal has to
# name that subproject's Configfile -- the line somebody would go and
# change -- and not just the two directories.
mkdir -p a-b a/b

cat >Configfile <<EOF
SUBPROJECTS += a-b
SUBPROJECTS += a
EOF
echo "SUBPROJECTS += b" > a/Configfile
echo "" > a-b/Configfile
echo "" > a/b/Configfile

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    cat out
    exit 1
fi
cat out

grep -q "pconfigure_subdir_a_b" out
head -n1 out | grep -q "a/Configfile:1 'SUBPROJECTS += b'"
grep -q "Configfile:1 'SUBPROJECTS += a-b'" out
test ! -e Makefile
