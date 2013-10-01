set -ex

ARCHIVE=`awk '/^__ARCHIVE_BELOW__/ {print NR + 1; exit 0; }' $0`
TMPDIR=`mktemp -d`
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

if [[ "$out" == "" ]]
then
    exit 0
else
    exit 1
fi

__ARCHIVE_BELOW__
