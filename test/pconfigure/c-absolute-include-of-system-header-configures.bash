#include "harness_start.bash"

# A header named by its absolute path need not be the project's own:
# here it is the system's stdio.h, which the scan now opens and reads
# like any other file it was pointed at.  Whatever that header
# includes in turn is on no include path the project gave, so it is
# passed over quietly, the way "#include <stdio.h>" itself always has
# been, and none of it may stop the configure or drag a source into
# the link.  The path is asked of the compiler so that the test means
# the same thing on any host.

mkdir -p src

stdio="$(echo '#include <stdio.h>' | ${CC:-cc} -E - \
    | sed -n 's@^# [0-9]* "\(/[^"]*/stdio\.h\)".*@\1@p' | head -n 1)"
test -f "$stdio"

cat >Configfile <<'EOF2'
LANGUAGES   += c

BINARIES    += app
SOURCES     += main.c
EOF2

cat >src/main.c <<EOF2
#include "$stdio"
int main(void) { printf("%d\n", 4); return 0; }
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
grep -q "^obj/src/main\.c/[^ ]*\.o: src/main\.c $stdio\$" Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "4"
