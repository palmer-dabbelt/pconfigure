#include "harness_start.bash"

# A SOURCES written twice the same way is one source: the second line
# names an object that already has a rule, and the link gets it once.
# Written twice in two spellings of the same path -- "main.c" and
# "./main.c" -- it was two sources, compiled to two objects
# (obj/src/main.c and obj/src/./main.c, which are the same directory
# under two make names) and linked twice, so the link fails on a
# duplicate "main".  What a path names is settled by normalizing it,
# which leaves_the_project() already does to decide whether it
# escapes; the same answer has to decide what it is called.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

for spelling in "./main.c" ".//main.c"
do
    cat >Configfile <<EOF
LANGUAGES += c

BINARIES  += main
SOURCES   += main.c
SOURCES   += $spelling
EOF
    cat Configfile

    $PTEST_BINARY $PCONFIGURE_ARGS
    make $MAKE_ARGS
    ./bin/main
    make $MAKE_ARGS clean
done
