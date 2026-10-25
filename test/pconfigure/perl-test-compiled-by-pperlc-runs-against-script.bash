#include "harness_start.bash"

# Perl goes through the same code BASH does: an included helper is
# pasted in and is a prerequisite, a TESTSRC written in perl is
# compiled by pperlc and run against the script, and its
# result says it passed.
mkdir -p src test/tool

cat >Configfile <<'EOF'
LANGUAGES += perl

BINARIES  += tool
SOURCES   += tool.pl
TESTSRC   += runs.pl
EOF

cat >src/tool.pl <<'EOF'
#include "helper.pl"
print "tool\n";
EOF

cat >src/helper.pl <<'EOF'
print "helper\n";
EOF

cat >test/tool/runs.pl <<'EOF'
my $out = `$ENV{PTEST_BINARY}`;
exit($out eq "helper\ntool\n" ? 0 : 1);
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
grep "^bin/tool:" Makefile | grep -q "src/helper.pl"
make $MAKE_ARGS
head -1 bin/tool | grep -q '^#!.*perl'
make $MAKE_ARGS check
test "$(tar -xOf check/tool/runs.pl ptest__return)" = 0

