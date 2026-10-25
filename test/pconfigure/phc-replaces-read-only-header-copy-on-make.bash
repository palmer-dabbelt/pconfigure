#include "harness_start.bash"

# A HEADERS with a SOURCES under it is copied into the include
# directory by phc while the project builds, so that what includes it
# finds it there.  phc's plain "cp" kept the source's mode and wrote
# through whatever copy was already there, so a source that is
# read-only gave a read-only copy -- and the first edit to the source
# after that left "make" unable to replace it: "cp: cannot create
# regular file 'include/x.h': Permission denied", for a file the build
# made itself.
mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES += c
LANGUAGES += h
HEADERS   += x.h
SOURCES   += x.h
EOF2

echo 'int x_one(void);' > src/x.h
chmod 444 src/x.h

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
grep -q x_one include/x.h

sleep 1
chmod 644 src/x.h
echo 'int x_two(void);' >> src/x.h
chmod 444 src/x.h

make $MAKE_ARGS
cat include/x.h
grep -q x_two include/x.h

make $MAKE_ARGS DESTDIR=$tempdir/dest install
grep -q x_two dest/usr/local/include/x.h
chmod -R u+w dest include
