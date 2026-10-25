#include "harness_start.bash"

# pperlc pastes a perl script's includes in the way pbashc does a bash
# one's, reading each line as the line it is.  A glob's "/" and "*"
# read as C open a comment that nothing closes, so the scan for what
# the script depends on would stop seeing anything below the glob,
# and editing an included file would never rebuild the script.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += perl

BINARIES  += tool
SOURCES   += tool.pl
EOF

cat >src/tool.pl <<'EOF'
my @f = glob("$ENV{HOME}/*");
#include "helper.pl"
print "tool\n";
EOF

cat >src/helper.pl <<'EOF'
print "old\n";
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/tool)" = "old
tool"

grep "^bin/tool:" Makefile | grep -q "src/helper.pl"

sleep 1
cat >src/helper.pl <<'EOF'
print "new\n";
EOF
make $MAKE_ARGS
test "$(./bin/tool)" = "new
tool"
