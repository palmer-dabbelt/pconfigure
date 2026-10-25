#include "harness_start.bash"

# pconfigure writes the build-tree copy of a .pc while it configures,
# beside the old copy, and only moves it over the old one once it is
# complete -- "so a sed that fails part way through doesn't replace a
# working copy with half of one".  That is judged by the pipeline's
# exit status, though, and a pipeline's status is its last command's:
# a sed that fails anywhere but last leaves the rest of the pipe
# writing an empty file successfully, which is then moved over the
# working copy.  A consumer's ppkg-config backtick is answered out of
# that copy, so it then finds a package with nothing in it.
mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES   += pkgconfig
LIBRARIES   += pkgconfig/x.pc
COMPILEOPTS += s/@@NAME@@/x/
SOURCES     += x.pc
EOF2

cat >src/x.pc <<'EOF2'
prefix=@@pconfigure_prefix@@
Name: @@NAME@@
Description: x
Version: 1
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
cat obj/pkgconfig/x.pc
grep -q "^Name: x$" obj/pkgconfig/x.pc

# A second option, put in front of the good one, that sed can't parse.
cat >Configfile <<'EOF2'
LANGUAGES   += pkgconfig
LIBRARIES   += pkgconfig/x.pc
COMPILEOPTS += s/^Version: 1/Version: 2
COMPILEOPTS += s/@@NAME@@/x/
SOURCES     += x.pc
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS || true
cat obj/pkgconfig/x.pc
grep -q "^Name: x$" obj/pkgconfig/x.pc
