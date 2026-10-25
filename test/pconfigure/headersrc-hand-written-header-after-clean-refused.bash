#include "harness_start.bash"

# A HEADERSRC whose copy is already in the include directory is
# accepted when the record of the copy's recipe, which every configure
# writes into the object directory, says this build made it.  That
# record used to outlive the copy: "make clean" removed include/x.h and
# left obj/include/x.h.recipe-inputs behind.  A header written into the
# include directory after the clean was then vouched for by a record
# that was about a different file, so the next configure accepted it,
# make compiled against it in place of src/x.h, and "make distclean"
# deleted it -- the very collision the refusal is there for.
#
# The clean now takes the record along with the copy, so a header
# written after it is one nothing vouches for, and it is refused.
mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c
LANGUAGES += h

HEADERSRC += x.h
EOF

echo '#define WHICH 2 /* from src */' > src/x.h

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
diff -u src/x.h include/x.h
test -f obj/include/x.h.recipe-inputs

make $MAKE_ARGS clean
test ! -e include/x.h
test ! -e obj/include/x.h.recipe-inputs

# Written after the source, which is the order in which make leaves a
# copy alone and compiles against whatever is there.
echo '#define WHICH 1 /* hand-written */' > include/x.h
touch -d '+2 seconds' include/x.h 2>/dev/null || { sleep 2; touch include/x.h; }

if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
then
    cat configure.out
    make $MAKE_ARGS
    grep WHICH include/x.h
    echo "a hand-written header after 'make clean' was accepted" >&2
    exit 1
fi
cat configure.out

grep -qF "Configfile:4 'HEADERSRC += x.h'" configure.out
grep -q "error: 'include/x.h' is already there" configure.out
grep -q "hand-written" include/x.h

# And a build that has been cleaned and not written into is one whose
# make still works: the Makefile writes the record back.
rm include/x.h
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS clean
make $MAKE_ARGS
diff -u src/x.h include/x.h
test -f obj/include/x.h.recipe-inputs

exit 0
