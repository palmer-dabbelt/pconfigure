set -ex

tempdir=`mktemp -d -t ptest-pbashc.XXXXXXXXXX`
trap "rm -rf $tempdir" EXIT
cd $tempdir
