set -ex

TMPDIR=`mktemp -d`
trap "rm -rf $TMPDIR" EXIT

cd $TMPDIR

touch Configfile
$PTEST_BINARY --version

test ! -f $tmpdir/Makefile
