set -ex
tempdir=`mktemp -d -t ptest.XXXXXXXXXX`
trap "rm -rf $tempdir" EXIT
cd $tempdir

# pclean -r limits it to the directory it was run in: the backups
# there go, the ones in subdirectories stay.  The flag is spelled the
# opposite way round from rm's, which is worth having written down
# somewhere that fails if it ever flips.
mkdir -p sub/deeper
touch top~ sub/mid~ sub/deeper/low~

$PTEST_BINARY -r

test ! -e top~
test -e sub/mid~
test -e sub/deeper/low~

# Without the flag the rest go too.
$PTEST_BINARY
test ! -e sub/mid~
test ! -e sub/deeper/low~

exit 0
