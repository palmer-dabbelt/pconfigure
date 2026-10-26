#include "harness_start.bash"

# The Makefile of a pconfigure from before recipe records vouches for a
# header copy only through the rule that made it.  One that names no
# records but has no rule for the file says nothing about it, and a
# header written there is somebody's, refused as it always was.
mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES += c
LANGUAGES += h

HEADERSRC += x.h
EOF2

echo '#define X 1' > src/x.h
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

find . -name '*.recipe-inputs' -delete
sed -i -e 's@ [^ ]*\.recipe-inputs@@g' -e '/recipe-inputs/d' Makefile

# The old Makefile had never heard of z.h.
cat >>Configfile <<'EOF2'
HEADERSRC += z.h
EOF2
echo '#define Z 1' > src/z.h
mkdir -p include
echo '#define Z 0 /* mine */' > include/z.h

if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
then
    cat configure.out
    echo "a hand-written header was taken for a copy" >&2
    exit 1
fi
cat configure.out

grep -qF "Configfile:5 'HEADERSRC += z.h'" configure.out
grep -qF "mine" include/z.h

exit 0
