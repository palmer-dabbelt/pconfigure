set -ex
tempdir=`mktemp -d -t ptest.XXXXXXXXXX`
trap "rm -rf $tempdir" EXIT
cd $tempdir

# What pclean is for: every name ending in '~' under the current
# directory is a backup and goes, however deep, whatever else is in the
# name -- spaces, a leading dash rm could read as an option, a leading
# dot that a shell glob would skip.  Anything not ending in '~' stays,
# including a file whose name merely contains one.
mkdir -p a/b/c 'dir with space'
touch -- main.c main.c~ a/x~ a/b/c/deep~ 'dir with space/s p~' '-rf~' '.hidden~'
touch -- 'tilde~in-middle' a/b/keep.h

$PTEST_BINARY > out.log
cat out.log

test ! -e main.c~
test ! -e a/x~
test ! -e a/b/c/deep~
test ! -e 'dir with space/s p~'
test ! -e ./-rf~
test ! -e .hidden~

test -e main.c
test -e 'tilde~in-middle'
test -e a/b/keep.h
test -d a/b/c
test -d 'dir with space'

# Each removal is named on stdout, one per line, by the path it was
# found at.  The order is whatever the directory walk gives, so the
# lines are compared sorted; what matters is that each backup is named
# once and nothing that stayed is named at all.
cat > expected.log <<'EOS'
./-rf~
./.hidden~
./a/b/c/deep~
./a/x~
./dir with space/s p~
./main.c~
EOS
LC_ALL=C sort out.log > sorted.log
LC_ALL=C sort expected.log | diff -u - sorted.log

# Nothing left to do is not an error, and says nothing.
$PTEST_BINARY > again.log
test ! -s again.log

exit 0
