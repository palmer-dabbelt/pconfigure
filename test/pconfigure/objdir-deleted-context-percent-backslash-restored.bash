#include "harness_start.bash"

# The configure-time files that come back after an object directory is
# deleted are written by printf from a recipe.  A '%' in what they say
# is a printf directive if it ever reaches the format rather than an
# argument, and a backslash is an escape to printf's format and to
# make's line continuation alike -- so this asks for both, alongside
# the escaped double quotes a "-DNAME=\"value\"" is usually spelled
# with, and checks the restored files are byte for byte what the
# configure wrote.

mkdir -p src

cat >Configfile <<'EOC'
AUTORECONFIGURE  = true
LANGUAGES       += c
COMPILEOPTS     += -DFMT='"%d|"' -DPATHX='"a\\b"' -DGREETING=\"hi\"
BINARIES        += main
SOURCES         += main.c
EOC

cat >src/main.c <<'EOC'
#include <stdio.h>
#ifdef GREETING
#include "extra.h"
#endif
int main(void)
{
    printf(FMT, extra());
    printf("%s %s\n", PATHX, GREETING);
    return 0;
}
EOC

echo 'int extra(void);' > src/extra.h
echo 'int extra(void) { return 7; }' > src/extra.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/main)" = '7|a\b hi'

mkdir saved
cp -r obj saved/
written="$(cd saved && find obj -name 'deps-context-*' -o -name link-inputs)"
test -n "$written"

# The point is what printf does with these characters, so make sure
# they really are in what was written: a test whose options got
# dropped before reaching the files would pass without proving
# anything.
(cd saved && cat $written) > saved-all
grep -qF '%d' saved-all
grep -qF '\\' saved-all
grep -qF '\"hi\"' saved-all

rm -rf obj bin
make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
test "$(./bin/main)" = '7|a\b hi'

for f in $written
do
    cmp "saved/$f" "$f"
done

# Put back by the Makefile rather than by a configure, since nothing
# in the Configfile changed.
if grep -q PCONFIGURE second.log
then
    exit 1
fi

# And a configure afterwards agrees with every restored file, so it
# rewrites none of them and leaves the build nothing to do.
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS > settled.log 2>&1 || { cat settled.log; exit 1; }
cat settled.log
grep -q "Nothing to be done" settled.log
