set -ex

TMPDIR=`mktemp -d`
trap "rm -rf $TMPDIR" EXIT

cd $TMPDIR

touch Configfile
pconfigure --version

test ! -f $tmpdir/Makefile
