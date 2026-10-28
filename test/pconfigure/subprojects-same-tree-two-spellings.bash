#include "harness_start.bash"

# A project two lines ask for is read once, and "the same project" is a
# question about the directory rather than about how the line spelled
# it: "a", "./a/" and "a//" are one tree.  Reading it twice would write
# its rules into the Makefile twice -- two recipes for every one of its
# targets -- and include its Makefile twice over.
mkdir -p src a/src

cat >Configfile <<EOF
SUBPROJECTS += a
SUBPROJECTS += ./a/
SUBPROJECTS += a//

LANGUAGES   += c
BINARIES    += top
LINKOPTS    += -La/lib
LINKOPTS    += -la
SOURCES     += top.c
EOF

cat >a/Configfile <<EOF
LANGUAGES   += c
LIBRARIES   += liba.so
SOURCES     += a.c
EOF

echo 'int a(void) { return 42; }' > a/src/a.c
cat >src/top.c <<EOF
#include <stdio.h>
int a(void);
int main(void) { printf("%d\n", a()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
cat out

# One include, one variable, one Makefile for the subproject.
test "$(grep -c '^include .*obj/Makefile.a$' Makefile)" = "1"
test "$(grep -c '^pconfigure_subdir_a ?=' Makefile)" = "1"
ls a/obj/Makefile.*
test "$(ls a/obj/Makefile.* | wc -l | tr -d ' ')" = "1"

# And make has nothing to warn about: a project read twice shows up as
# "overriding recipe".
make $MAKE_ARGS > make.out 2>&1
cat make.out
if grep -q "overriding recipe" make.out
then
    exit 1
fi
test "$(./bin/top)" = "42"

exit 0
