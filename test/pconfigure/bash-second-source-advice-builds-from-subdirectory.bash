#include "harness_start.bash"

# A second SOURCES on a BASH target is refused with the "#include" to
# write in the first source instead.  pinclude looks a quoted include
# up from the directory of the file doing the including, so with both
# sources under lib/ the name to write is "b.bash" -- the "lib/b.bash"
# the Configfile spells it as would be looked for in lib/lib/ and fail
# the build.  So this doesn't just read the advice: it follows it, the
# way a user would, and checks the result builds and runs both files.
mkdir -p src/lib

cat >Configfile <<'EOF2'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += lib/a.bash
SOURCES   += lib/b.bash
EOF2

cat >src/lib/a.bash <<'EOF2'
echo from-a
EOF2

cat >src/lib/b.bash <<'EOF2'
echo from-b
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS > pconfigure.out 2>&1
then
    cat pconfigure.out
    exit 1
fi
cat pconfigure.out
test ! -e Makefile

grep -q "Configfile:5 'SOURCES += lib/b.bash'" pconfigure.out
grep -q "write '#include \"b.bash\"' in lib/a.bash" pconfigure.out

# Take the line out of the message rather than writing it here, so
# what's tested is the advice as given.
include="$(sed -n "s/^.*write '\(#include \"[^\"]*\"\)' in lib\/a.bash.*$/\1/p" pconfigure.out)"
test -n "$include"
echo "$include" >> src/lib/a.bash
sed -i.bak '/SOURCES   += lib\/b.bash/d' Configfile
cat Configfile src/lib/a.bash

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
./bin/tool > out
cat out
grep -qx "from-a" out
grep -qx "from-b" out
