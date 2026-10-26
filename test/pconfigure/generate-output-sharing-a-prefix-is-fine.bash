#include "harness_start.bash"

# The directory check is about one output landing inside another, not
# about names that merely start the same way: "sub-x.h" and "sub.h"
# next to "sub/y.h" share no path in obj/proc, so all three have to
# keep building.

mkdir -p src/sub

cat >Configfile <<EOF
LANGUAGES += c
GENERATE  += sub-x.h
GENERATE  += sub/y.h
GENERATE  += sub.h
BINARIES  += app
SOURCES   += app.c
EOF

cat >src/sub-x.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--generate) echo "#define X 1" ;;
esac
EOF
cat >src/sub/y.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--generate) echo "#define Y 2" ;;
esac
EOF
cat >src/sub.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--generate) echo "#define Z 3" ;;
esac
EOF
chmod +x src/sub-x.h.proc src/sub/y.h.proc src/sub.h.proc

cat >src/app.c <<'EOF'
#include "sub-x.h"
#include "sub/y.h"
#include "sub.h"
int main(void) { return X + Y + Z - 6; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
./bin/app

exit 0
