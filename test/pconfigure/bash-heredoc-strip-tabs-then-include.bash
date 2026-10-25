#include "harness_start.bash"

# A "<<-" heredoc may end at a tab-indented delimiter, which is how a
# heredoc inside a function body is written.  Both readers have to see
# that line as the end of the body, or the include after it is either
# swallowed by pbashc or missing from the prerequisites.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

printf 'f() {\n\tcat <<-END\n\t#include "nothing.h"\n\tEND\n}\nf\n#include "helper.bash"\necho tool\n' > src/tool.bash

cat >src/helper.bash <<'EOF'
echo helper
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/tool)" = '#include "nothing.h"
helper
tool'
grep "^bin/tool:" Makefile | grep -q "src/helper.bash"
if grep "^bin/tool:" Makefile | grep -q "nothing.h"
then
    exit 1
fi
