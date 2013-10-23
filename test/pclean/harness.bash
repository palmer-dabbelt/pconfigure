set -ex

#############################################################################
# Run the test without valgrind                                             #
#############################################################################
ARCHIVE=`awk '/^__ARCHIVE_BELOW__/ {print NR + 1; exit 0; }' $0`
TMPDIR=`mktemp -d -t ptest.XXXXXXXXXX`
trap "rm -rf $TMPDIR" EXIT

echo ""
echo ""
echo ""

echo "Extracting"
tail -n+$ARCHIVE $0 | base64 -d | tar xzv -C $TMPDIR
echo ""
echo ""
echo ""

CDIR=`pwd`
cd $TMPDIR/work
echo "Running"
$PTEST_BINARY

cd $TMPDIR
out="$(diff -ur *)"

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
TMPDIR=`mktemp -d -t ptest.XXXXXXXXXX`
trap "rm -rf $TMPDIR" EXIT

echo ""
echo ""
echo ""

echo "Extracting"
tail -n+$ARCHIVE $0 | base64 -d | tar xzv -C $TMPDIR
echo ""
echo ""
echo ""

CDIR=`pwd`
cd $TMPDIR/work
echo "Running"

valgrind -q $PTEST_BINARY 2> test.valgrind

if [[ "$(cat test.valgrind | wc -l)" != "0" ]]
then
    exit 2
fi

rm test.valgrind

cd $TMPDIR
out="$(diff -ur *)"

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
