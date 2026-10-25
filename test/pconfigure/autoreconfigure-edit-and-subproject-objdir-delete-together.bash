#include "harness_start.bash"

# A Configfile edited and a subproject's object directory deleted, both
# before the same make, are two rules that each want to run pconfigure.
# Under -j those could be two configures writing every Makefile in the
# tree side by side; the rule for the missing Makefile waits on the top
# one, so they run one after the other and the second finds everything
# already written.  What has to come out is the edit built, the
# subproject built again, and a tree that settles.
# subproject-objdir-deleted-reconfigures.bash covers the deletion on
# its own and serially; this is the two together, in parallel.
#
# The outcome alone can't see the ordering: two configures side by side
# happen to write the same files, and the tree comes out right anyway
# most of the time.  So every recipe line goes through a shell that
# notes when a pconfigure starts and ends, and holds each one open long
# enough that two which were allowed to overlap would.  The recipe names
# pconfigure by its full path, which is why this wraps the shell rather
# than putting a pconfigure on PATH.

mkdir -p src sub/src

cat >wrapsh <<'EOF'
#!/bin/bash
case "$2" in
*/pconfigure|*/pconfigure\ *)
    echo "start" >> "$PCONFIGURE_RUNS"
    sleep 2
    /bin/bash "$@"
    status=$?
    echo "end" >> "$PCONFIGURE_RUNS"
    exit $status
    ;;
esac
exec /bin/bash "$@"
EOF
chmod +x wrapsh

cat >Configfile <<'EOF'
AUTORECONFIGURE  = true
SUBPROJECTS     += sub
LANGUAGES       += c
BINARIES        += top
SOURCES         += top.c
EOF

cat >sub/Configfile <<'EOF'
LANGUAGES       += c
BINARIES        += subbin
SOURCES         += sub.c
EOF

for f in src/top.c src/added.c sub/src/sub.c
do
    echo 'int main(void) { return 0; }' > "$f"
done

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test -x sub/bin/subbin
test ! -e bin/added

sleep 1
cat >>Configfile <<'EOF'
BINARIES        += added
SOURCES         += added.c
EOF
rm -rf sub/obj sub/bin

PCONFIGURE_RUNS="$(pwd)/runs.log" make $MAKE_ARGS -j2 SHELL="$(pwd)/wrapsh" \
    > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
cat runs.log
grep -q "^PCONFIGURE$" second.log

# Each start is followed by its own end before the next start: nothing
# ran two configures at once.  The first line has to be a start, or the
# wrapper matched nothing and the check below says nothing.
test "$(head -n 1 runs.log)" = "start"
test "$(tail -n 1 runs.log)" = "end"
test "$(uniq -d runs.log | wc -l)" = 0
test -x bin/added
test -x sub/bin/subbin
test -e sub/obj/Makefile.sub

make $MAKE_ARGS -j2 > third.log 2>&1
cat third.log
grep -q "Nothing to be done" third.log
if grep -q "^PCONFIGURE$" third.log
then
    exit 1
fi

exit 0
