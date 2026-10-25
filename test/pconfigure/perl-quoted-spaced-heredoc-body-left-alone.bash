#include "harness_start.bash"

# Perl lets blanks sit between "<<" and its terminator when that
# terminator is quoted, so '<< "EOT"' is still a heredoc even though
# '1 << 4' is a shift.  The include in its body is text the script
# prints rather than one it reads, so it has to come out as written
# and stay off the script's prerequisites.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += perl

BINARIES  += tool
SOURCES   += tool.pl
EOF

cat >src/tool.pl <<'EOF'
print << "EOT";
#include "helper.pl"
EOT
print "tool\n";
EOF

cat >src/helper.pl <<'EOF'
print "helper\n";
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
if grep "^bin/tool:" Makefile | grep -q "src/helper.pl"
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/tool)" = '#include "helper.pl"
tool'
