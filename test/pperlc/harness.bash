set -ex

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
tail -n+$ARCHIVE $0 | base64 --decode | tar xzv -C $TMPDIR
echo ""
echo ""
echo ""

CDIR=`pwd`
cd $TMPDIR
echo "Running"

valgrind -q $PTEST_BINARY -i in.pl -o out.pl >& test.valgrind

if [[ "$(cat test.valgrind | wc -l)" != "0" ]]
then
    exit 2
fi

cd $TMPDIR
out="$(diff -ur out.pl gold.pl)"

cd $CDIR
rm -rf $TMPDIR

if [[ "$out" == "" ]]
then
    exit 0
else
    exit 1
fi

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
tail -n+$ARCHIVE $0 | base64 --decode | tar xzv -C $TMPDIR
echo ""
echo ""
echo ""

CDIR=`pwd`
cd $TMPDIR
echo "Running"
$PTEST_BINARY -i in.pl -o out.pl

cd $TMPDIR
out="$(diff -ur out.pl gold.pl)"

cd $CDIR
rm -rf $TMPDIR

if [[ "$out" == "" ]]
then
    exit 0
else
    exit 1
fi

#############################################################################
# Exit here to avoid running the archive                                    #
#############################################################################
exit 0

__ARCHIVE_BELOW__
