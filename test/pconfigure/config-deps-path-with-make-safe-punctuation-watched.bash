#include "harness_start.bash"

# The punctuation in a CONFIG_DEPS name that means nothing to make on a
# prerequisite list or to the "$(wildcard ...)" glob -- an '=', a '%', a
# ',', a '+', an '@' -- reaches the reconfigure rule as written and is
# watched like any other name: a make settles, and editing the file
# reconfigures.  A ',' is the interesting one, since it separates a
# function's arguments, but "$(wildcard)" takes only one and the rest of
# the text is that one.

mkdir -p src

names='a=b.txt 50%.txt x,y.txt c++.txt me@host.txt'

{
    echo 'AUTORECONFIGURE  = true'
    for name in $names
    do
        echo "CONFIG_DEPS     += $name"
    done
    echo 'LANGUAGES       += c'
    echo 'BINARIES        += main'
    echo 'SOURCES         += main.c'
} > Configfile

echo 'int main(void) { return 0; }' > src/main.c
for name in $names
do
    echo 1 > "$name"
done

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

for name in $names
do
    make $MAKE_ARGS > settled.log 2>&1 || { cat settled.log; exit 1; }
    if grep -q PCONFIGURE settled.log
    then
        cat settled.log
        exit 1
    fi

    sleep 1
    echo 2 > "$name"
    make $MAKE_ARGS > edited.log 2>&1 || { cat edited.log; exit 1; }
    cat edited.log
    grep -q PCONFIGURE edited.log
done
