#include "harness_start.bash"

##############################################################################
# A script "make install" put in place is one "make uninstall" removes      #
##############################################################################
# A bash BINARIES is installed by the bash language's own install rule
# rather than by the cp rule a compiled program gets, and only that cp
# rule ever put itself on "uninstall".  So "make uninstall" took the C
# program out of $PREFIX/bin and left the script sitting beside where
# it had been -- including one installed under a nested name.  Perl
# is built and installed by the same code as bash, so a perl script
# was left behind the same way.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c
echo 'echo hello' > src/script.bash
echo 'echo nested' > src/nested.bash
echo 'print "hello\n";' > src/hello.pl

cat >Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash
LANGUAGES += perl

BINARIES  += main
SOURCES   += main.c

BINARIES  += script
SOURCES   += script.bash

BINARIES  += tools/nested
SOURCES   += nested.bash

BINARIES  += hello
SOURCES   += hello.pl
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS DESTDIR=$tempdir/dest install

test -f dest/usr/local/bin/main
test -f dest/usr/local/bin/script
test -f dest/usr/local/bin/tools/nested
test -f dest/usr/local/bin/hello

make $MAKE_ARGS DESTDIR=$tempdir/dest uninstall

# Every file rather than the ones named above, so that whatever the
# next install rule writes is covered without anybody remembering to
# add it here.
find dest -type f > left
cat left
test ! -s left

# Uninstalling is about the copy under the prefix.  What the build
# made in bin/ is the build's, and "make clean" is what takes it.
test -f bin/script
test -f bin/tools/nested
test -f bin/hello
