set -ex

ARCHIVE=`awk '/^__ARCHIVE_BELOW__/ {print NR + 1; exit 0; }' $0`
tempdir=`mktemp -d -t ptest.XXXXXXXXXX`
trap "rm -rf $tempdir" EXIT

echo ""
echo ""
echo ""

echo "Extracting"
tail -n+$ARCHIVE $0 | base64 --decode | tar xzv -C $tempdir
echo ""
echo ""
echo ""

CDIR=`pwd`
cd $tempdir
echo "Running"

rm -f Configfile.local
find -name "Configfile" | xargs cat
$PTEST_BINARY $ARGS

cat Makefile
make

if test -x ./update
then
    sleep 2s
    ./update
    sleep 2s
    make
fi

make check
ptest --verbose || exit 1

./bin/test > test.out

out="$(diff -u test.out test.gold)"

make D=$(pwd)/install DESTDIR=$(pwd)/install install

find bin* lib* -type f | while read f
do
    if test ! -f $(pwd)/install/usr/local/$f
    then
        exit 1
    fi
done

cd $CDIR
rm -rf $tempdir

if [[ "$out" != "" ]]
then
    exit 1
fi

#############################################################################
# Exit here to avoid running the archive                                    #
#############################################################################
exit 0

__ARCHIVE_BELOW__
