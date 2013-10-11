set -ex

#############################################################################
# Run the test without valgrind                                             #
#############################################################################
ARCHIVE=`awk '/^__ARCHIVE_BELOW__/ {print NR + 1; exit 0; }' $0`
TMPDIR=`mktemp -d`
trap "rm -rf $TMPDIR" EXIT

echo ""
echo ""
echo ""

echo "Extracting"

tail -n+$ARCHIVE $0 | base64 -d | tar xzv -C $TMPDIR

CDIR=`pwd`
export LD_LIBRARY_PATH=`pwd`/lib

cd $TMPDIR/input
$PTEST_BINARY $(cat $TMPDIR/filename) |& sort > $TMPDIR/stdout.test

cd $TMPDIR
cat $TMPDIR/stdout.gold | sort > $TMPDIR/stdout.gold.sorted
out="$(diff -ur $TMPDIR/stdout.test $TMPDIR/stdout.gold.sorted)"

echo ""
echo ""
echo ""
echo "Expected"
cat $TMPDIR/stdout.gold

echo ""
echo ""
echo ""
echo "Got"
cat $TMPDIR/stdout.test

cd $CDIR
rm -rf $TMPDIR

if [[ "$out" != "" ]]
then
    exit 1
fi

#############################################################################
# Run the test with valgrind                                                #
#############################################################################
ARCHIVE=`awk '/^__ARCHIVE_BELOW__/ {print NR + 1; exit 0; }' $0`
TMPDIR=`mktemp -d`
trap "rm -rf $TMPDIR" EXIT

echo ""
echo ""
echo ""

echo "Extracting"

tail -n+$ARCHIVE $0 | base64 -d | tar xzv -C $TMPDIR

CDIR=`pwd`
export LD_LIBRARY_PATH=`pwd`/lib

cd $TMPDIR/input
valgrind -q $PTEST_BINARY $(cat $TMPDIR/filename) |& sort > $TMPDIR/stdout.test

cd $TMPDIR
cat $TMPDIR/stdout.gold | sort > $TMPDIR/stdout.gold.sorted
out="$(diff -ur $TMPDIR/stdout.test $TMPDIR/stdout.gold.sorted)"

echo ""
echo ""
echo ""
echo "Expected"
cat $TMPDIR/stdout.gold

echo ""
echo ""
echo ""
echo "Got"
cat $TMPDIR/stdout.test

cd $CDIR
rm -rf $TMPDIR

if [[ "$out" != "" ]]
then
    exit 1
fi

#############################################################################
# Exit here to avoid running the archive                                    #
#############################################################################
exit 0

__ARCHIVE_BELOW__
