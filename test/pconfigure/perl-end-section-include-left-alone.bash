#include "harness_start.bash"

# "__END__" ends a Perl script the same way "__DATA__" does: what
# comes after it is never compiled, and is where a script keeps its
# POD or anything else it wants out of the way.  An include written
# down there -- in an example, say -- is text, and the include above
# it still has to be one.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += perl

BINARIES  += tool
SOURCES   += tool.pl
EOF

cat >src/tool.pl <<'EOF'
#include "helper.pl"
print "tool\n";
__END__
=head1 EXAMPLE

#include "missing.pl"
EOF

cat >src/helper.pl <<'EOF'
print "helper\n";
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
grep "^bin/tool:" Makefile | grep -q "src/helper.pl"

make $MAKE_ARGS
test "$(./bin/tool)" = "helper
tool"
grep -q '^#include "missing.pl"$' bin/tool
