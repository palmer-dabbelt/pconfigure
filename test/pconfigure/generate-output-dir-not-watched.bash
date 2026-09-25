#include "harness_start.bash"

# A GENERATE's dep report is re-derived during the build (see
# generate-late-input-appears.bash), and the directories it names are
# watched via $(wildcard <dir>) so a file arriving into one of them is
# noticed.  But a GENERATE's own output -- the generated file itself,
# and the .d fragment tracking its deps -- lands in that same
# gen_dir, by default obj/proc.  If one GENERATE's snapshot happens to
# name a path inside gen_dir (its own directory, or a sibling
# GENERATE's), gen_dir ends up in the watched set, and building the
# target writes into the very directory being watched: gen_dir's mtime
# moves forward, the .d rule sees itself as stale again, and it
# rebuilds forever without ever settling. A `make` that never finishes
# is what this pins against: two plain GENERATEs, the second's --deps
# naming the first's output, must settle after one build.

mkdir -p src

cat >Configfile <<EOF2
LANGUAGES += c

GENERATE  += gen1.h
GENERATE  += gen2.h

BINARIES  += app
SOURCES   += app.c
EOF2

cat >src/gen1.h.proc <<'EOF2'
#!/bin/bash
case "$1" in
--deps)     ;;
--generate) echo "#define ONE 1" ;;
esac
EOF2
chmod +x src/gen1.h.proc

# gen2's snapshot names gen1's generated output, which lives in the
# same default gen_dir (obj/proc) that gen2's own output and .d
# fragment land in too -- the shape that makes gen_dir land in the
# watched set for gen2's own DEPS rule.
cat >src/gen2.h.proc <<'EOF2'
#!/bin/bash
case "$1" in
--deps)     echo "obj/proc/gen1.h" ;;
--generate) echo "#define TWO 2" ;;
esac
EOF2
chmod +x src/gen2.h.proc

cat >src/app.c <<'EOF2'
  #include "gen1.h"
  #include "gen2.h"
  #include <stdio.h>
int main(void) { printf("%d\n", ONE + TWO); return 0; }
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS

# A build that never settles hangs here; bound it so the test fails
# loudly (not by wedging the whole suite) if the loop comes back.
timeout 60 make $MAKE_ARGS > first.out 2>&1 || { cat first.out; exit 1; }
cat first.out
test "$(./bin/app)" = "3"

# The point: a second plain make has nothing to do. A regression here
# means gen_dir is (still, or again) watching itself.
timeout 60 make $MAKE_ARGS > settled.out 2>&1 || { cat settled.out; exit 1; }
cat settled.out
grep -q "Nothing to be done" settled.out

exit 0
