#include "harness_start.bash"

# Perl has had "<<~" since 5.26: a heredoc whose body, and whose
# terminator, may be indented.  The shell has no such thing -- to it
# "<<~EOT" is a heredoc that ends at a line saying "~EOT" -- and a
# Perl script used to be read with the shell's rules.  The heredoc
# then never ended, swallowing the rest of the file: pperlc refused
# the include below it, and pconfigure left that include off the
# script's prerequisites.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += perl

BINARIES  += tool
SOURCES   += tool.pl
EOF

# Indented with both spaces and a tab, since "<<~" takes either and
# a "<<-" style reading would stop at tabs alone.
printf '%s\n' \
    'print <<~EOT;' \
    "  	hello" \
    "  	EOT" \
    '#include "helper.pl"' \
    'print "tool\n";' \
    >src/tool.pl

cat >src/helper.pl <<'EOF'
print "helper\n";
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# The include after the heredoc is one the script reads, so editing
# it has to rebuild the script.
grep "^bin/tool:" Makefile | grep -q "src/helper.pl"

make $MAKE_ARGS
test "$(./bin/tool)" = "hello
helper
tool"
