#include "harness_start.bash"

# "$x <<= 2" is Perl's shift-and-assign.  An "=" can't be a heredoc's
# terminator in Perl, yet pperlc reads "<<=" after a blank as a
# heredoc ending at a line saying "=", which no line does: the include
# below is refused as swallowed, and pconfigure's scan quietly leaves
# it off the script's prerequisites.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += perl

BINARIES  += tool
SOURCES   += tool.pl
EOF

cat >src/tool.pl <<'EOF'
my $x = 3;
$x <<= 2;
#include "helper.pl"
print "tool $x\n";
EOF

cat >src/helper.pl <<'EOF'
print "helper\n";
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
grep "^bin/tool:" Makefile | grep -q "src/helper.pl"

make $MAKE_ARGS
test "$(./bin/tool)" = "helper
tool 12"
