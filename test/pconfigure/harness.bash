set -ex

#############################################################################
# Run the test without valgrind                                             #
#############################################################################
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

$PTEST_BINARY

make

if test -x ./update
then
    sleep 2s
    ./update
    sleep 2s
    make
fi

./bin/test > test.out

out="$(diff -u test.out test.gold)"

cd $CDIR
rm -rf $tempdir

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

ARCHIVE=`awk '/^__ARCHIVE_BELOW__/ {print NR + 1; exit 0; }' $0`
tempdir=`mktemp -d -t ptest.XXXXXXXXXX`
trap "rm -rf $tempdir" EXIT

echo ""
echo ""
echo ""

export PATH="$(dirname $PTEST_BINARY):$PATH"

echo "Extracting"
tail -n+$ARCHIVE $0 | base64 --decode | tar xzv -C $tempdir
echo ""
echo ""
echo ""

CDIR=`pwd`
cd $tempdir
echo "Running"

valgrind -q $PTEST_BINARY >& test.valgrind
cat test.valgrind

if [[ "$(cat test.valgrind | wc -l)" != 0 ]]
then
    exit 1
fi

make

if test -x ./update
then
    sleep 2s
    ./update
    sleep 2s
    make
fi

./bin/test > test.out

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
