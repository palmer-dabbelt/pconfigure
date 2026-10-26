#include "harness_start.bash"

# Perl allows a blank between "<<" and a quoted terminator, so
# 'print << "END";' opens a heredoc ending at "END".  The C include in
# its body is text the script prints, left in the output by pperlc and
# off the script's prerequisites; the include after "END" is the
# script's own, pasted and listed.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += perl

BINARIES  += tool
SOURCES   += tool.pl
EOF

cat >src/tool.pl <<'EOF'
print << "END";
#include "stdio.h"
END
#include "helper.pl"
print "tool\n";
EOF

cat >src/helper.pl <<'EOF'
print "helper\n";
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
grep "^bin/tool:" Makefile | grep -q "src/helper.pl"
if grep "^bin/tool:" Makefile | grep -q "stdio.h"
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/tool)" = '#include "stdio.h"
helper
tool'
