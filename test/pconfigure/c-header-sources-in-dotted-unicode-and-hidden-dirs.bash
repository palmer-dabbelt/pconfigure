#include "harness_start.bash"

# The source behind a header is found by swapping the header's ending
# for a source's, and an ending is the last component's -- so a dot in
# a directory name ("v1.0/x.h"), a directory that is all UTF-8 and
# dashes, and a hidden directory whose name starts with a dot must not
# be read as part of one.  Each header here has its source beside it
# and nothing lists that source, so the program only links if the scan
# found all three.
mkdir -p "src/v1.0" "src/ünï-x" src/.hidden

echo 'int f(void);' > src/v1.0/x.h
printf '#include "x.h"\nint f(void) { return 0; }\n' > src/v1.0/x.c
echo 'int g(void);' > "src/ünï-x/y.h"
printf '#include "y.h"\nint g(void) { return 0; }\n' > "src/ünï-x/y.c"
echo 'int h(void);' > src/.hidden/z.h
printf '#include "z.h"\nint h(void) { return 0; }\n' > src/.hidden/z.c

cat >src/main.c <<'EOF'
#include "v1.0/x.h"
#include "ünï-x/y.h"
#include ".hidden/z.h"
int main(void) { return f() + g() + h(); }
EOF

cat >Configfile <<EOF
LANGUAGES += c
BINARIES  += main
SOURCES   += main.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
./bin/main

# And an edit to one of them rebuilds the program.
sleep 1
printf '#include "y.h"\nint g(void) { return 3; }\n' > "src/ünï-x/y.c"
make $MAKE_ARGS
set +e
./bin/main
status=$?
set -e
test "$status" = 3
