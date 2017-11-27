find -name "Configfile" | xargs cat
$PTEST_BINARY $PCONFIGURE_ARGS

cat Makefile
make $MAKE_ARGS

if test -x ./update
then
    sleep 2s
    ./update
    sleep 2s
    make
fi

make $MAKE_ARGS check
ptest --verbose || exit 1

./bin/test > test.out

if test -e test.gold.proc
then
    ./test.gold.proc > test.gold
fi

out="$(diff -u test.out test.gold)"

make D=$(pwd)/install DESTDIR=$(pwd)/install install

find bin* lib* -type f | while read f
do
    if test ! -f $(pwd)/install/usr/local/$f
    then
        exit 1
    fi
done

if [[ "$out" != "" ]]
then
    exit 1
fi
