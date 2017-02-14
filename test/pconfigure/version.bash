set -ex

TMPDIR=`mktemp -d -t ptest.XXXXXXXXXX`
trap "rm -rf $TMPDIR" EXIT

cd $TMPDIR

touch Configfile
$PTEST_BINARY --version

test ! -f $TMPDIR/Makefile
