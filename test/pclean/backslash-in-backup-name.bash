set -ex
tempdir=`mktemp -d -t ptest.XXXXXXXXXX`
trap "rm -rf $tempdir" EXIT
cd $tempdir

# pclean removes every "*~" under the current directory, reading the
# names find prints back one at a time.  A plain "read" treats a
# backslash in what it reads as an escape and drops it, so a backup
# called 'a\b~' comes back as 'ab~': pclean then removes 'ab~' --
# a different file -- and leaves the one it found where it was.
touch 'a\b~'
touch 'ab~'
touch 'keep'

$PTEST_BINARY

# Every backup is gone, including the one with the backslash in it.
test ! -e 'a\b~'
test ! -e 'ab~'

# And what wasn't a backup is still there.
test -f keep

# The same with only the backslashed one present: there is no 'ab~'
# for the mangled name to land on, so the removal it attempts fails.
touch 'c\d~'
$PTEST_BINARY
test ! -e 'c\d~'

exit 0
