#include "harness_start.bash"

# An absolute "#include" that names nothing is still an error pointing
# at its line, but the places pbashc lists as having looked are the
# ones a relative name is looked for in, and an absolute one is looked
# for in none of them.  Naming the script's own directory there would
# send whoever reads it looking for the file somewhere it was never
# going to be found.

mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES += bash
BINARIES  += x
SOURCES   += x.bash
EOF2

cat >src/x.bash <<EOF2
#include "$tempdir/nowhere/l.bash"
echo x
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
if make $MAKE_ARGS > make.out 2>&1
then
    cat make.out
    exit 1
fi
cat make.out
grep -q "src/x.bash:1: can't find '$tempdir/nowhere/l.bash'" make.out
grep -q "absolute path" make.out
if grep -q "looked in" make.out
then
    exit 1
fi
