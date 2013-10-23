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

CDIR=`pwd`
export LD_LIBRARY_PATH=`pwd`/lib

cd $tempdir/input
$PTEST_BINARY $(cat $tempdir/filename) |& sort > $tempdir/stdout.test

cd $tempdir
cat $tempdir/stdout.gold | sort > $tempdir/stdout.gold.sorted
out="$(diff -ur $tempdir/stdout.test $tempdir/stdout.gold.sorted)"

echo ""
echo ""
echo ""
echo "Expected"
cat $tempdir/stdout.gold

echo ""
echo ""
echo ""
echo "Got"
cat $tempdir/stdout.test

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

echo "Extracting"

tail -n+$ARCHIVE $0 | base64 --decode | tar xzv -C $tempdir

CDIR=`pwd`
export LD_LIBRARY_PATH=`pwd`/lib

cd $tempdir/input
valgrind -q $PTEST_BINARY $(cat $tempdir/filename) |& sort > $tempdir/stdout.test

cd $tempdir
cat $tempdir/stdout.gold | sort > $tempdir/stdout.gold.sorted
out="$(diff -ur $tempdir/stdout.test $tempdir/stdout.gold.sorted)"

echo ""
echo ""
echo ""
echo "Expected"
cat $tempdir/stdout.gold

echo ""
echo ""
echo ""
echo "Got"
cat $tempdir/stdout.test

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
