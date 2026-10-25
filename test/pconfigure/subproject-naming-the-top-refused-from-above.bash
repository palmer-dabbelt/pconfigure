#include "harness_start.bash"

# "SUBPROJECTS += .." in "a" names the directory "a" sits in.  Run in
# "a" that is climbing out and is refused.  Run from the top it names
# the top project, which is no more a subproject of "a" than "a" is of
# itself -- it is the project that pulled "a" in.  Resolved against
# "a/" it comes out as the empty path, and an empty path is what ends
# the loop that reads subprojects, so the line used to be accepted and
# then quietly dropped: a Makefile was written as though it had never
# been there.  It is refused from the top as well, naming a's line.
mkdir -p src a/src

cat >Configfile <<EOF2
SUBPROJECTS += a

LANGUAGES   += c
BINARIES    += top
SOURCES     += top.c
EOF2

cat >a/Configfile <<EOF2
SUBPROJECTS += ..

LANGUAGES   += c
LIBRARIES   += liba.so
SOURCES     += a.c
EOF2

echo 'int main(void) { return 0; }' > src/top.c
echo 'int a(void) { return 0; }' > a/src/a.c

if (cd a && $PTEST_BINARY $PCONFIGURE_ARGS) > inside.out 2>&1
then
    cat inside.out
    exit 1
fi
cat inside.out
grep -q "SUBPROJECTS can't reach outside the project" inside.out

if $PTEST_BINARY $PCONFIGURE_ARGS > above.out 2>&1
then
    cat above.out
    exit 1
fi
cat above.out
grep -q "SUBPROJECTS can't point at a directory that contains it" above.out
grep -q "a/Configfile:1 'SUBPROJECTS += \.\.'" above.out
test ! -e Makefile

exit 0
