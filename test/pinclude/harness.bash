ARCHIVE=`awk '/^__ARCHIVE_BELOW__/ {print NR + 1; exit 0; }' $0`
TMPDIR=`mktemp -d`

tail -n+$ARCHIVE $0 | base64 -d | tar xzv -C $TMPDIR

CDIR=`pwd`
export LD_LIBRARY_PATH=`pwd`/lib

cd $TMPDIR/input
$PTEST_BINARY $(cat $TMPDIR/filename) | sort > $TMPDIR/stdout.test

cd $TMPDIR
out="$(diff -ur $TMPDIR/stdout.test $TMPDIR/stdout.gold)"

cd $CDIR
rm -rf $TMPDIR

if [[ "$out" == "" ]]
then
    exit 0
else
    exit 1
fi

__ARCHIVE_BELOW__
