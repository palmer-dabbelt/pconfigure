#include "harness_start.bash"

# A GENERATE in a subproject runs its script from the subproject's
# directory, as "(cd sub/. && script --generate) > out".  Under CDPATH
# the cd prints where it went, inside the parentheses whose output is
# the generated file -- so the header started with an absolute path
# and every source that included it failed to compile.  The same cd
# runs the script's --deps while configuring, and the printed path
# became one of gen.h's prerequisites.
#
# Both places it runs from are covered: pconfigure runs the script
# itself while configuring, and make runs the recipe again whenever the
# script changes, and those are two different shells with two
# different environments.
mkdir -p sub/src
echo 'SUBPROJECTS += sub' > Configfile

cat >sub/Configfile <<'EOF'
LANGUAGES += c
GENERATE  += gen.h
BINARIES  += app
SOURCES   += app.c
EOF

cat >sub/src/gen.h.proc <<'EOF'
case "$1" in
--deps)     ;;
--generate) echo "#define ANSWER 42" ;;
esac
EOF
chmod +x sub/src/gen.h.proc

cat >sub/src/app.c <<'EOF'
#include "gen.h"
#include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

export CDPATH=.
$PTEST_BINARY
make $MAKE_ARGS > make.out 2>&1 || { cat make.out; find . -name gen.h -exec cat {} \; ; exit 1; }
cat make.out
test "$(./sub/bin/app)" = 42

# Nothing the build depends on is the project's own directory.
if grep -q "$(pwd)" sub/obj/Makefile.sub
then
    grep -n "$(pwd)" sub/obj/Makefile.sub
    exit 1
fi

# The script changes, so make regenerates the header from its own
# recipe -- with the CDPATH of the shell make was started in.
sed -i 's/42/43/' sub/src/gen.h.proc
make $MAKE_ARGS > remake.out 2>&1 || { cat remake.out; find . -name gen.h -exec cat {} \; ; exit 1; }
cat remake.out
test "$(./sub/bin/app)" = 43
