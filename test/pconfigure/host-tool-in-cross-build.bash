#include "harness_start.bash"

# A cross tree's generators are a different build from its target
# objects: Kbuild's hostprogs compile with HOSTCC and host flags
# whatever the target compiler is doing (taxonomy types 13 and 14).
# pconfigure has no hostprogs concept -- what it has is CROSS_COMPILE,
# a prefix on the language's compiler name, and a value that can be
# cleared between blocks: a binary declared after "CROSS_COMPILE ="
# with nothing after the equals sign builds with the host compiler in
# the very same Configfile that cross-compiles its neighbors.
#
# So the test says the split directly, with a fake toolchain whose
# every invocation is logged: the generator binary builds with the
# host compiler, the target binary compiles with the cross compiler,
# and the generator's *source* change relinks the generator with the
# host compiler, regenerates its output, and recompiles the target
# source with the cross compiler -- the whole chain, with neither
# compiler stepping on the other's work.
#
# The GENERATE line stands between the two blocks on purpose: the
# include it adds to the include path has to exist while the target's
# SOURCES line is being read, and the tool's own block has already
# closed its CROSS_COMPILE by then.

mkdir -p src tc

cat >tc/faketc-gcc <<EOF
#!/bin/bash
echo "faketc-gcc \$@" >> "$PWD/tc/ran.log"
exec cc "\$@"
EOF

cat >tc/faketc-g++ <<EOF
#!/bin/bash
echo "faketc-g++ \$@" >> "$PWD/tc/ran.log"
exec c++ "\$@"
EOF

chmod +x tc/faketc-gcc tc/faketc-g++
export PATH="$PWD/tc:$(dirname "$PTEST_BINARY"):$PATH"

cat >Configfile <<EOF
LANGUAGES += c

CROSS_COMPILE = faketc-

BINARIES  += gen
CROSS_COMPILE =
SOURCES   += gen.c

GENERATE  += gen.h

CROSS_COMPILE = faketc-

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

# The split is in the Makefile, spelled per rule: the generator's
# source compiles with the host compiler, the target's source with the
# cross compiler, and no rule puts the cross prefix on the generator.
grep -qE '\$\{CC\} -x c .* -c src/gen\.c -o ' Makefile
if grep -qE 'faketc.* -c src/gen\.c' Makefile
then
    exit 1
fi
grep -qE 'faketc-gcc -x c .* -c src/app\.c -o ' Makefile

# The target object reaches the generator only through the generated
# output: the tool's binary is not a prerequisite of the compile rule,
# the generated header is.
if grep -qE '^obj/src/app\.c/.*static\.o:.*bin/gen' Makefile
then
    exit 1
fi

# And the generator ran: the header carries the real answer, not the
# placeholder the configure-time run wrote.
test "$(cat obj/proc/gen.h)" = "#define ANSWER 10"

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

# In order, with no step skipped: the generator relinked -- with the
# host compiler, no cross-compiler invocation on gen.c recorded
# before or after ...
test "$(grep -cE 'faketc.* -c src/gen\.c' tc/ran.log)" -eq 0
grep -q "^LD	gen$" second.out

# ... its output was regenerated from the new binary ...
grep -q "^GEN	gen.h$" second.out
test "$(grep -n '^LD	gen$' second.out | cut -d: -f1)" -lt "$(grep -n '^GEN	gen.h$' second.out | cut -d: -f1)"

# ... and the target source recompiled with the cross compiler and
# relinked after that.
grep -q "^CC	app.c$" second.out
grep -q "^LD	app$" second.out
test "$(grep -n '^GEN	gen.h$' second.out | cut -d: -f1)" -lt "$(grep -n '^CC	app.c$' second.out | cut -d: -f1)"

# The answer the binary gives is the new generator's answer.
test "$(./bin/app)" = "11"

exit 0
