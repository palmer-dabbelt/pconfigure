#include "harness_start.bash"

# Perl reads its switches from the "#!" line, and only from the first
# line of the file.  pperlc used to put its own "#!/usr/bin/perl" there
# and move the script's line down underneath it, so "-w" on a script's
# shebang was silently gone from the compiled program: the warnings
# the author turned on never appeared.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += perl

BINARIES  += tool
SOURCES   += tool.pl
EOF

cat >src/tool.pl <<'EOF'
#!/usr/bin/perl -w
my $x;
print "x=" . $x . "\n";
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
cat bin/tool

head -n 1 bin/tool | grep -qx '#!.*/usr/bin/perl -w'
test "$(grep -c '^#!' bin/tool)" = 1

./bin/tool > tool.out 2> tool.err
cat tool.out tool.err
grep -q "uninitialized" tool.err
