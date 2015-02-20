set -ex

#############################################################################
# Run the test without valgrind                                             #
#############################################################################
$PTEST_BINARY $ARGS -i in.bash -o out.bash

out="$(diff -ur out.bash gold.bash)"

if [[ "$out" != "" ]]
then
    exit 1
fi

#############################################################################
# Run the test with valgrind                                                #
#############################################################################
if [[ "$(which valgrind)" == "" ]]
then
    exit 0
fi

if test ! -x `which valgrind`
then
    exit 0
fi

valgrind -q $PTEST_BINARY $ARGS -i in.bash -o out.bash >& test.valgrind
cat test.valgrind

if [[ "$(cat test.valgrind | wc -l)" != "0" ]]
then
    exit 1
fi

out="$(diff -ur out.bash gold.bash)"

if [[ "$out" != "" ]]
then
    exit 1
fi
