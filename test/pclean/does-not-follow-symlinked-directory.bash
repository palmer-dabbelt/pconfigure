set -ex
tempdir=`mktemp -d -t ptest.XXXXXXXXXX`
trap "rm -rf $tempdir" EXIT
cd $tempdir

# pclean cleans the tree it is run in and nothing it merely points at.
# A symlink to a directory elsewhere is not walked, so the backups in
# that directory are left alone; and a symlink whose own name ends in
# '~' is a backup like any other file, so the link goes and what it
# pointed at doesn't.
mkdir -p elsewhere project
touch elsewhere/theirs~ elsewhere/target

ln -s ../elsewhere project/linked
ln -s ../elsewhere/target project/link~
touch project/mine~

cd project
$PTEST_BINARY
cd ..

test ! -e project/mine~
test ! -L project/link~
test -L project/linked
test -e elsewhere/theirs~
test -e elsewhere/target

exit 0
