#include "harness_start.bash"

# "1 << 4" in Perl is a left shift.  A heredoc's "<<" can't have a
# space between it and an unquoted terminator -- Perl has refused
# that spelling outright since 5.28 -- so a "<<" followed by a blank
# and a bare word or number is never the start of one.  pperlc reads
# it with the shell's rule instead, takes "4" for a terminator, and
# then refuses the include below it as the body of a heredoc that
# never ends.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += perl

BINARIES  += tool
SOURCES   += tool.pl
EOF

cat >src/tool.pl <<'EOF'
my $mask = 1 << 4;
#include "helper.pl"
print "tool $mask\n";
EOF

cat >src/helper.pl <<'EOF'
print "helper\n";
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
grep "^bin/tool:" Makefile | grep -q "src/helper.pl"

make $MAKE_ARGS
test "$(./bin/tool)" = "helper
tool 16"
