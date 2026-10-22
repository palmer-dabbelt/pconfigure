#include "harness_start.bash"

# The uninstall rules are spelled out of the same "$(DESTDIR)/..."
# words as the install ones, and with a space in DESTDIR the "rm -f"
# they run is handed both halves of the name: "rm -f /tmp/.../stage
# dir//usr/local/bin/main".  That removes a file called "stage" next
# to the staging directory and a "dir/usr/local/bin/main" in the
# source tree, neither of which the uninstall has any business with,
# and leaves what was installed where it was.  It has to be refused
# the same way the install is.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfile <<EOF
LANGUAGES += c

BINARIES  += main
SOURCES   += main.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

# Something installed the honest way, plus the two innocent
# bystanders a split DESTDIR would point the "rm" at.
mkdir "$tempdir/stage dir"
ln -s "$tempdir/stage dir" "$tempdir/stage-link"
make $MAKE_ARGS DESTDIR="$tempdir/stage-link" install
test -x "$tempdir/stage dir/usr/local/bin/main"
echo bystander > "$tempdir/stage"
mkdir -p dir/usr/local/bin
echo bystander > dir/usr/local/bin/main

if make $MAKE_ARGS DESTDIR="$tempdir/stage dir" uninstall > uninstall.out 2>&1
then
    cat uninstall.out
    exit 1
fi
cat uninstall.out
grep -F 'DESTDIR' uninstall.out

test -f "$tempdir/stage"
test -f dir/usr/local/bin/main
test -x "$tempdir/stage dir/usr/local/bin/main"
