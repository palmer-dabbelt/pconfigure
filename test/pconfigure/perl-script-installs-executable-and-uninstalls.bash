#include "harness_start.bash"

# A Perl script is built and installed by the same code as a BASH one,
# so it gets the same install: a 0755 copy under $PREFIX/bin that is
# byte for byte the script in the tree, whatever umask built it, and
# taken back out by "make uninstall".  The script's #include is pasted
# in by pperlc, so what is installed runs on its own.
mkdir -p src
cat > src/tool.pl <<'EOF2'
#!/usr/bin/perl
#include "greet.pl"
greet();
EOF2
cat > src/greet.pl <<'EOF2'
sub greet { print "hello\n"; }
EOF2

cat >Configfile <<'EOF2'
LANGUAGES += perl
BINARIES  += tools/tool
SOURCES   += tool.pl
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
(umask 077 && make $MAKE_ARGS)
make $MAKE_ARGS DESTDIR=$tempdir/dest install

cmp bin/tools/tool dest/usr/local/bin/tools/tool
if test "$(uname -s)" = "Darwin"; then
	test "$(stat -f %Lp dest/usr/local/bin/tools/tool)" == 755
else
	test "$(stat -c %a dest/usr/local/bin/tools/tool)" == 755
fi
test "$(dest/usr/local/bin/tools/tool)" == hello

make $MAKE_ARGS DESTDIR=$tempdir/dest uninstall
test -z "$(find dest -type f)"
