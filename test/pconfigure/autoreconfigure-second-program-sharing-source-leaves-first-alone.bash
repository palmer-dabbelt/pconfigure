#include "harness_start.bash"

# Adding a second program built from a source the first already uses
# changes nothing about the first: its compile line, its object and
# its link are what they were.  The new program does get a dependency
# fragment of its own for the shared source -- each fragment names the
# links its object goes on -- so pdeps has to be asked about the
# source again, and that is all that should happen to it.
#
# The header-list stamp the object restales on used to sit beside the
# fragment, one per consumer, so the new program's stamp was written
# after the object it describes: the shared object was recompiled and
# the first program relinked, for a list of headers the object had
# been compiled against all along.  The stamp belongs to the object,
# and a new consumer finds it already there.
mkdir -p src
echo 'int main(void) { return 0; }' > src/hello.c
cat >Configfile <<'EOF2'
AUTORECONFIGURE = true
LANGUAGES += c
BINARIES  += hello
SOURCES   += hello.c
EOF2

$PTEST_BINARY
make
cp -p bin/hello hello.before
sleep 1

cat >>Configfile <<'EOF2'
BINARIES  += second
SOURCES   += hello.c
EOF2
make > second.out 2>&1
cat second.out
test -x bin/second
if grep -q "$(printf 'CC\thello.c$')" second.out
then
    exit 1
fi
if grep -q "$(printf 'LD\thello$')" second.out
then
    exit 1
fi
test ! bin/hello -nt hello.before

# Two fragments describing one object share one stamp, and neither
# pdeps run may leave it saying something the other would rewrite: a
# stamp that changed with whichever fragment was derived last would
# restale the object on every build.  So the build has settled, and
# the next make has nothing to say.
make > third.out 2>&1
cat third.out
grep -q "Nothing to be done" third.out
if grep -q "$(printf '\t')" third.out
then
    exit 1
fi
