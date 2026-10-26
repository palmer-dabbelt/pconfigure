#include "harness_start.bash"

# The quieter half of the same staleness: the header the edited script
# starts including has no source to link, so nothing fails -- the
# object just doesn't depend on it.  pconfigure scanned the generated
# header that was on disk when it was rerun, which the old script
# wrote, so extra.h is on no rule, and editing it afterwards leaves a
# binary built from the old value with make saying there was nothing
# to do.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c
GENERATE  += gen.h
BINARIES  += app
SOURCES   += app.c
EOF

cat >src/gen.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--generate) echo "#define ANSWER 1" ;;
esac
EOF
chmod +x src/gen.h.proc

cat >src/extra.h <<'EOF'
#define EXTRA 10
EOF

cat >src/app.c <<'EOF'
#include "gen.h"
#include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "1"

sleep 2
cat >src/gen.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--generate) echo '#include "../../src/extra.h"'
            echo "#define ANSWER EXTRA" ;;
esac
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "10"

sleep 2
echo "#define EXTRA 20" > src/extra.h
make $MAKE_ARGS
test "$(./bin/app)" = "20"

exit 0
