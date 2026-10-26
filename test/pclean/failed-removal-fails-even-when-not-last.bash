set -ex
tempdir=`mktemp -d -t ptest.XXXXXXXXXX`
# The read-only directory below has to be made writable again before
# rm -rf can take it apart.
trap 'chmod -R u+w "$tempdir"; rm -rf "$tempdir"' EXIT
cd $tempdir

# pclean is "rm *~, recursively", and rm fails when any file it was
# given couldn't be removed.  pclean removes one backup at a time,
# though, and used to finish with the status of the last rm it ran: a
# backup it couldn't remove was reported on stderr and then forgotten
# as soon as another one was removed after it, so a script running
# pclean was told everything went.
#
# Root removes files from a read-only directory regardless, so there
# is nothing to test there.
if test "$(id -u)" = 0
then
    echo "SKIP: root can remove a file from a read-only directory"
    exit 0
fi

# The backup that can't go is in a read-only directory.  Which order
# find walks a directory in is up to the filesystem, so the failure
# being forgotten can only be seen on a run where the stuck backup
# wasn't the last name pclean printed.  With twenty removable backups
# beside it a run like that comes along almost at once, and a run
# where it was last still has to fail, so every run is checked.
checked=false
for attempt in $(seq 1 10)
do
    mkdir -p "try$attempt/ro"
    cd "try$attempt"
    touch ro/stuck~
    for n in $(seq 1 20)
    do
        touch "b$n~"
    done
    chmod a-w ro

    status=0
    $PTEST_BINARY > out.log 2> err.log || status=$?
    cat out.log err.log

    # Everything else went, the stuck one didn't, and pclean said so.
    test -e ro/stuck~
    test -z "$(find . -name 'b*~')"
    test "$status" != 0

    cd ..
    if test "$(tail -n1 "try$attempt/out.log")" != "./ro/stuck~"
    then
        checked=true
        break
    fi
done

$checked
