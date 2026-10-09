#include "harness_start.bash"

# "make reconfigure" runs pconfigure again.  Which pconfigure is the
# question this test is about: the one that wrote the Makefile, named
# by location, and not whatever $PATH turns up.
#
# A tree that vendors pconfigure and builds it into src/pconfigure/bin
# has never installed one, so $PATH has no answer and the bare name
# named nothing.  That made "make reconfigure" the one rule that could
# not run on a tree where every other rule worked -- and it is not a
# rule anybody can route around, because it is also the recipe make
# uses to remake the Makefile when a Configfile is newer than it.
#
# Every directory holding a pconfigure comes off $PATH below, which is
# the state of a machine that has never installed one.  They go one at
# a time rather than $PATH being emptied, because reconfiguring still
# has to find a compiler: the point is that *pconfigure* is not on
# $PATH, not that nothing is.
scrubbed=()
IFS=: read -ra path_dirs <<<"$PATH"
for dir in "${path_dirs[@]}"
do
    if [[ -x "$dir/pconfigure" ]]
    then
        continue
    fi

    scrubbed+=("$dir")
done
export PATH="$(IFS=:; echo "${scrubbed[*]}")"

# The premise of everything below.  Checked rather than assumed,
# because a test that silently stopped scrubbing would keep passing
# while testing nothing.
if command -v pconfigure
then
    echo "pconfigure is still on PATH, so this test proves nothing" >&2
    exit 1
fi

mkdir -p src

cat >Configfile <<EOF2
LANGUAGES   += c

BINARIES    += test
SOURCES     += test.c
EOF2

cat >src/test.c <<EOF2
#include <stdio.h>
int main(void) { printf("%d\n", 7); return 0; }
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# The recipe has to name a pconfigure that exists.  "pwd -P" because
# pconfigure asks the kernel where it is, and on macOS that resolves
# the symlink a temporary directory sits behind.
grep -qE "^\s+@?$(dirname "$PTEST_BINARY")/pconfigure " Makefile

# And it has to run.  This is the symptom, named directly: with a bare
# name the shell writes "command not found" and make stops.
make $MAKE_ARGS reconfigure 2>reconfigure.stderr || {
    cat reconfigure.stderr >&2
    echo "make reconfigure could not run pconfigure" >&2
    exit 1
}
cat reconfigure.stderr

if grep -q "command not found" reconfigure.stderr
then
    echo "make reconfigure went looking for pconfigure on PATH" >&2
    exit 1
fi

# The same recipe remakes the Makefile when a Configfile is newer, so
# that path has to work too rather than only the phony somebody types.
sleep 2s
touch Configfile
make $MAKE_ARGS 2>remake.stderr
cat remake.stderr

if grep -q "command not found" remake.stderr
then
    echo "the Makefile remake went looking for pconfigure on PATH" >&2
    exit 1
fi

# The tree still builds, which is what all of that was for.
make $MAKE_ARGS
test "$(./bin/test)" = "7"

exit 0
