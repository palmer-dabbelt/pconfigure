#include "harness_start.bash"

# The llvm-tblgen shape: a tool the project builds from its own
# sources generates a header the project's other sources include, and
# the chain has to arrive in order -- generator relinked, output
# regenerated, includers recompiled -- when the generator's source
# changes (taxonomy types 2, 7, 13; §2B).  Nothing in pconfigure puts
# the tool on the generated rule's prerequisite line, so the edge is
# spelled by hand in the GENERATE script: the "--deps" answer names
# the tool's own binary, which has a rule of its own because it is a
# BINARIES entry.
#
# The script also answers for the configure-time run, where the tool
# does not exist yet: it writes a placeholder, and the first build
# replaces the placeholder with the tool's real answer before anything
# reads the header.  That the real answer, not the placeholder, is
# what the consumer was compiled against is part of the order the
# assertions below check.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

BINARIES  += gen
SOURCES   += gen.c

GENERATE  += gen.h

BINARIES  += app
SOURCES   += app.c
EOF

cat >src/gen.c <<'EOF'
#include <stdio.h>
int main(void) { printf("#define ANSWER 10\n"); return 0; }
EOF

cat >src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     echo "src/gen.c bin/gen" ;;
--generate) if test -x bin/gen; then bin/gen > obj/proc/gen.h; else echo "#define ANSWER 0" > obj/proc/gen.h; fi ;;
esac
EOF
chmod +x src/gen.h.proc

cat >src/app.c <<'EOF'
  #include "gen.h"
  #include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS > first.out 2>&1
cat first.out
test "$(./bin/app)" = "10"

# The placeholder never survived to a consumer: the tool was built,
# the header was regenerated from it, and app.c was compiled after
# that, in that order -- the order the generated rules spell and the
# log below can be read in.
grep -q "^LD	gen$" first.out
grep -q "^GEN	gen.h$" first.out
grep -q "^CC	app.c$" first.out
test "$(grep -n '^LD	gen$' first.out | cut -d: -f1)" -lt "$(grep -n '^GEN	gen.h$' first.out | cut -d: -f1)"
test "$(grep -n '^GEN	gen.h$' first.out | cut -d: -f1)" -lt "$(grep -n '^CC	app.c$' first.out | cut -d: -f1)"

# A build that has nothing to do is the ordinary answer from here on,
# which is what makes the build after the edit mean something.
make $MAKE_ARGS > settled.out 2>&1
cat settled.out
grep -q "Nothing to be done" settled.out

##############################################################################
# The generator's source changes                                             #
##############################################################################
sleep 2
printf '#include <stdio.h>\nint main(void) { printf("#define ANSWER 11\\n"); return 0; }\n' > src/gen.c

make $MAKE_ARGS > second.out 2>&1
cat second.out

# In order, with no step skipped: the generator relinked ...
grep -q "^LD	gen$" second.out

# ... its output was regenerated, by the new binary rather than the
# old one ...
grep -q "^GEN	gen.h$" second.out
test "$(grep -n '^LD	gen$' second.out | cut -d: -f1)" -lt "$(grep -n '^GEN	gen.h$' second.out | cut -d: -f1)"

# ... and the includer recompiled after that and relinked.
grep -q "^CC	app.c$" second.out
grep -q "^LD	app$" second.out
test "$(grep -n '^GEN	gen.h$' second.out | cut -d: -f1)" -lt "$(grep -n '^CC	app.c$' second.out | cut -d: -f1)"

# The answer the binary gives is the new generator's answer, the part
# a stale regeneration or a stale object would each get wrong in a
# different way.
test "$(./bin/app)" = "11"

exit 0
