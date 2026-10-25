set -ex
tempdir=`mktemp -d -t ptest.XXXXXXXXXX`
trap "rm -rf $tempdir" EXIT
cd $tempdir

# find hands each name over NUL-terminated precisely so that any byte
# a file name can hold survives the trip, newlines included.  The
# "read" on the other end still treats a backslash followed by a
# newline as a line continuation and drops both, so a backup whose
# name has one in it is never the name pclean tries to remove.
name=$'odd\\\nname~'
touch "$name"
touch keep

$PTEST_BINARY

test ! -e "$name"
test -f keep

exit 0
