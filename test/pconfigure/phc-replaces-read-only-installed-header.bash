#include "harness_start.bash"

# phc used to install a header with a bare "cp input output".  cp
# gives a new file the mode of the one it copies, so a header that is
# read-only in the tree -- a generated one, or a checkout from a tool
# that hands out files read-only until they are opened for edit -- was
# installed read-only.  And cp without -f writes through an existing
# destination rather than replacing it, so the next "make install"
# after the header changed couldn't open the copy it made last time:
# "Permission denied", and the old header stayed installed.  Every
# other install rule copies beside the destination and renames over
# it, which is indifferent to the old file's mode, and phc has to too.
mkdir -p include

cat >Configfile <<'EOF2'
LANGUAGES += c
HEADERS   += x.h
EOF2

echo 'int x_one(void);' > include/x.h
chmod 444 include/x.h

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS DESTDIR=$tempdir/dest install
grep -q x_one dest/usr/local/include/x.h

sleep 1
chmod 644 include/x.h
echo 'int x_two(void);' >> include/x.h
chmod 444 include/x.h

make $MAKE_ARGS DESTDIR=$tempdir/dest install
cat dest/usr/local/include/x.h
grep -q x_two dest/usr/local/include/x.h

# Leave nothing the harness can't remove.
chmod -R u+w dest
