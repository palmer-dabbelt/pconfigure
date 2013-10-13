set -ex

#############################################################################
# Run the test with valgrind                                                #
#############################################################################
ARCHIVE=`awk '/^__ARCHIVE_BELOW__/ {print NR + 1; exit 0; }' $0`
TMPDIR=`mktemp -d`
trap "rm -rf $TMPDIR" EXIT

echo ""
echo ""
echo ""

export PATH="$(dirname $(readlink -f $PTEST_BINARY)):$PATH"

echo "Extracting"
tail -n+$ARCHIVE $0 | base64 -d | tar xzv -C $TMPDIR
echo ""
echo ""
echo ""

CDIR=`pwd`
cd $TMPDIR
echo "Running"

valgrind -q $PTEST_BINARY >& test.valgrind
if [[ "$(cat test.valgrind | wc -l)" != 0 ]]
then
    exit 2
fi

make

if test -x ./update
then
    sleep 1s
    ./update
    make
fi

./bin/test > test.out

out="$(diff -u test.out test.gold)"

cd $CDIR
rm -rf $TMPDIR

if [[ "$out" != "" ]]
then
    exit 1
fi

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
echo ""
echo ""
echo ""

CDIR=`pwd`
cd $TMPDIR
echo "Running"

$PTEST_BINARY

make

if test -x ./update
then
    ./update
    make
fi

./bin/test > test.out

out="$(diff -u test.out test.gold)"

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
