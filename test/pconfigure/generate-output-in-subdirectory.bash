#include "harness_start.bash"

# A GENERATE may name a file in a directory of its own: "sub/gen.h"
# stays inside the project, so the escape check lets it through, and
# its script is looked for at src/sub/gen.h.proc the same way a SOURCES
# in a subdirectory is.  The output then belongs at obj/proc/sub/gen.h,
# which is where '#include "sub/gen.h"' looks for it.  The recipe used
# to make only obj/proc itself before redirecting into obj/proc/sub/,
# so the redirect failed for want of a directory and the configure
# aborted on a shell error about a temporary file nobody wrote.

mkdir -p src/sub

cat >Configfile <<EOF
LANGUAGES += c

GENERATE  += sub/gen.h

BINARIES  += app
SOURCES   += app.c
EOF

echo 3 > src/sub/answer.txt

cat >src/sub/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     echo "src/sub/answer.txt" ;;
--generate) echo "#define ANSWER $(cat src/sub/answer.txt)" ;;
esac
EOF
chmod +x src/sub/gen.h.proc

cat >src/app.c <<'EOF'
  #include "sub/gen.h"
  #include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# The configure-time run wrote the output where the include looks for
# it, and the record of the fragment's recipe sits beside it rather
# than one directory up where a "gen.h" of the top directory would
# keep its own.
test -f obj/proc/sub/gen.h
test -f obj/proc/sub/gen.h.d-context
test ! -e obj/proc/gen.h.d-context

make $MAKE_ARGS
test "$(./bin/app)" = "3"

# The fragment of build-time prerequisites lands in the same
# subdirectory, and it is the one the Makefile includes.
test -f obj/proc/sub/gen.h.d
test ! -e obj/proc/gen.h.d

# The build-time copy of the recipe has to make the directory too, and
# that is checked on the rule itself: deleting obj/proc/sub and running
# make again would not show it, because the fragment goes with the
# directory, make rebuilds that included fragment before anything else,
# and the fragment's own recipe makes its directory -- so a GEN rule
# that made only obj/proc would still find obj/proc/sub waiting.
grep -A1 -F "@echo \"GEN	sub/gen.h\"" Makefile >gen-rule
grep -qxF "	@mkdir -p obj/proc/sub" gen-rule

# Regenerating with the directory gone still has to work end to end,
# even though it is the fragment's recipe that makes the place first.
sleep 1
echo 5 > src/sub/answer.txt
rm -rf obj/proc/sub
make $MAKE_ARGS
test "$(./bin/app)" = "5"
test -f obj/proc/sub/gen.h

exit 0
