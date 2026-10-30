#include "harness_start.bash"

# A tree built by a pconfigure from before recipe records were kept has
# none for any header copy in it.  Once a header source is edited, the
# first configure by a pconfigure that does keep them finds a copy with
# no record that says something its source doesn't -- which is what a
# hand-written header looks like too, so it was refused.  That is every
# tree that vendors pconfigure, on its first build after an update that
# touched a header.  The Makefile the old pconfigure wrote is the record
# that tree has: it has the rule that made the copy, and it names no
# recipe records, which every Makefile written since does.  So the copy
# is taken for one, and written over by the build.
mkdir -p src sub/src

cat >Configfile <<'EOF2'
SUBPROJECTS += sub

LANGUAGES += c
LANGUAGES += h

HEADERSRC += x.h
EOF2

cat >sub/Configfile <<'EOF2'
LANGUAGES += c
LANGUAGES += h

HEADERSRC += y.h
EOF2

echo '#define X 1' > src/x.h
echo '#define Y 1' > sub/src/y.h
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
diff -u src/x.h include/x.h
diff -u sub/src/y.h sub/include/y.h

# What the old pconfigure left: the same rules, and no records.
find . -name '*.recipe-inputs' -delete
for m in $(grep -rl 'recipe-inputs' --include='Makefile*' .)
do
    sed -i.bak -e 's@ [^ ]*\.recipe-inputs@@g' -e '/recipe-inputs/d' "$m"
done

sleep 1
echo '#define X 2' > src/x.h
echo '#define Y 2' > sub/src/y.h

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
diff -u src/x.h include/x.h
diff -u sub/src/y.h sub/include/y.h

exit 0
