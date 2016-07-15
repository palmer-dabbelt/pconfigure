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
ptest || exit 1

./bin/test > test.out

make D=$(pwd)/install DESTDIR=$(pwd)/install install

out="$(diff -u test.out test.gold)"

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
