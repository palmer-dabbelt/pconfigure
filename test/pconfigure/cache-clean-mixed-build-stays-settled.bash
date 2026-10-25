#include "harness_start.bash"

# "make cache-clean" reads the Makefile back and removes whatever
# under the object directory it no longer names.  A project that
# builds a bit of everything -- a static archive, a shared library, a
# program linked against both, a compiled script, a generated header,
# and a C and a BASH test -- leaves a lot of different kinds of file
# in there, and every one the build still needs has to survive: the
# build after a cache-clean has nothing to do, and the tests are not
# rerun.
mkdir -p src test/app

cat >Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash

GENERATE  += gen.h

LIBRARIES += libs.a
SOURCES   += one.c

LIBRARIES += libd.so
SOURCES   += two.c

BINARIES  += app
DEPLIBS   += s
DEPLIBS   += d
SOURCES   += app.c
TESTSRC   += t.c
TESTSRC   += b.bash

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     echo "src/v.txt" ;;
--generate) echo "#define V $(cat src/v.txt)" ;;
esac
EOF
chmod +x src/gen.h.proc
echo 4 > src/v.txt

echo 'int one(void) { return 1; }' > src/one.c
echo 'int two(void) { return 2; }' > src/two.c
cat >src/app.c <<'EOF'
  #include "gen.h"
  #include <stdio.h>
int one(void);
int two(void);
int main(void) { printf("%d\n", V + one() + two()); return 0; }
EOF

cat >test/app/t.c <<'EOF'
int main(void) { return 0; }
EOF

cat >test/app/b.bash <<'EOF'
#include "expect.bash"
test "$($PTEST_BINARY)" = "$EXPECT"
EOF
echo 'EXPECT=7' > test/app/expect.bash

cat >src/tool.bash <<'EOF'
#!/bin/bash
#include "inc.bash"
EOF
echo 'echo tool' > src/inc.bash

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS all check
test "$(./bin/app)" = "7"

make $MAKE_ARGS cache-clean

# Nothing it took is something the build needs back.
make $MAKE_ARGS -q all check

# And what it kept still works.
test "$(./bin/app)" = "7"
test "$(./bin/tool)" = "tool"
test -f obj/proc/gen.h

exit 0
