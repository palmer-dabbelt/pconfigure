#include "harness_start.bash"

# "<<~" is Perl's indented heredoc, and Perl scripts are read knowing
# that.  To bash it means nothing special: "<<~EOT" is a heredoc whose
# delimiter is the word "~EOT", ended by a line saying exactly that.
# A shell script has to keep being read the shell's way, or the
# heredoc below would end at the indented "EOT" inside its body and
# the "#include" after that would be expanded out of the text the
# script writes.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/tool.bash <<'OUTER'
cat <<~EOT
    EOT
#include "helper.bash"
~EOT
#include "helper.bash"
OUTER

cat >src/helper.bash <<'EOF'
echo helper
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
./bin/tool >out
cat >expected <<'EOF'
    EOT
#include "helper.bash"
helper
EOF
diff -u expected out
