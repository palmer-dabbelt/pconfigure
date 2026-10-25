#include "harness_start.bash"

# Everything after a Perl script's "__DATA__" line is data the script
# reads rather than script -- the Perl counterpart of a heredoc's
# body, and used for the same thing: a template for a file the script
# writes.  A heredoc's "#include" lines are left alone for exactly
# that reason, but "__DATA__" used to mean nothing here, so a C
# template's "#include <stdio.h>" was read as a directive that
# pperlc couldn't find, and the script wouldn't compile.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += perl

BINARIES  += tool
SOURCES   += tool.pl
EOF

cat >src/tool.pl <<'EOF'
print while <DATA>;
__DATA__
#include <stdio.h>
#include "helper.pl"
int main(void) { return 0; }
EOF

# A file the data happens to name, which is there so that reading the
# line as an include would find something.  The script never reads
# it, so it is no prerequisite of the script either.
cat >src/helper.pl <<'EOF'
print "helper\n";
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

if grep "^bin/tool:" Makefile | grep -q "src/helper.pl"
then
    exit 1
fi

make $MAKE_ARGS
./bin/tool >out.c
cat >expected.c <<'EOF'
#include <stdio.h>
#include "helper.pl"
int main(void) { return 0; }
EOF
diff -u expected.c out.c
