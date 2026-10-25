#include "harness_start.bash"

# A GENERATE whose name has a directory in it, inside a subproject.
# The directory the recipe makes is the one the output goes in, and
# from a parent that is spelled through the subproject's prefix just
# like the output itself: a recipe that made "obj/proc/sub" of the
# directory make was started in would make the wrong one and leave the
# redirect with nowhere to write.

mkdir -p lib/src/sub

cat >Configfile <<EOF
SUBPROJECTS += lib
EOF

cat >lib/Configfile <<EOF
LANGUAGES += c

GENERATE  += sub/gen.h

BINARIES  += app
SOURCES   += app.c
EOF

cat >lib/src/sub/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--generate) echo "#define ANSWER 8" ;;
esac
EOF
chmod +x lib/src/sub/gen.h.proc

cat >lib/src/app.c <<'EOF'
  #include "sub/gen.h"
  #include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
cat lib/obj/Makefile.lib

test -f lib/obj/proc/sub/gen.h
test ! -e obj/proc

make $MAKE_ARGS
test "$(./lib/bin/app)" = "8"
test -f lib/obj/proc/sub/gen.h.d

# The subproject's GEN rule makes the output's own directory, spelled
# through the subproject's prefix.  This is checked on the rule rather
# than by deleting the directory and building again, since the
# fragment's recipe would remake the directory before GEN ran and hide
# a GEN rule that forgot to.
grep -A1 -F "@echo \"GEN	sub/gen.h\"" lib/obj/Makefile.lib >gen-rule
grep -qxF "	@mkdir -p \$(pconfigure_subdir_lib)obj/proc/sub" gen-rule

# Regenerated from the parent with the directory gone, the output comes
# back in the subproject and nothing appears in the parent.
rm -rf lib/obj/proc/sub
make $MAKE_ARGS
test -f lib/obj/proc/sub/gen.h
test ! -e obj/proc

# And from inside the subproject, where the same rule has no prefix to
# go through and has to name the same directory.
cd lib
rm -rf obj bin
$PTEST_BINARY $PCONFIGURE_ARGS
grep -A1 -F "@echo \"GEN	sub/gen.h\"" Makefile >../gen-rule-inside
grep -qxF "	@mkdir -p obj/proc/sub" ../gen-rule-inside
rm -rf obj/proc/sub
make $MAKE_ARGS
test "$(./bin/app)" = "8"
test -f obj/proc/sub/gen.h
cd ..

exit 0
