#include "harness_start.bash"

# The optional spelling of generate-deps-last-line-without-newline.bash.
# A "?src/opt/answer.txt" printed with no newline after it used to come
# through the configure as "?src/opt/answer.tx", and an optional input
# loses a letter far more quietly than a mandatory one does: the glob
# around a path that will never exist expands to nothing, so make has
# no complaint at all.  What kept the build working was the fragment
# the build re-derives with sed, which takes the line whole -- the
# configure's own rule was watching nothing, and an answer the two
# halves disagree about is one a later change to either can break
# without a word.  So the rule is checked for the whole path, and the
# arrival is checked to be heard.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h

BINARIES  += app
SOURCES   += app.c
EOF

cat >src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     printf '?src/opt/answer.txt' ;;
--generate) if test -f src/opt/answer.txt
            then echo "#define ANSWER $(cat src/opt/answer.txt)"
            else echo "#define ANSWER 0"
            fi ;;
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

grep -q "^obj/proc/gen.h: .*\$(wildcard [^)]*src/opt/answer.txt)" Makefile

timeout 60 make $MAKE_ARGS > first.out 2>&1 || { cat first.out; exit 1; }
cat first.out
test "$(./bin/app)" = "0"

# The input arrives, newer than the output, and the next plain make has
# to hear it.
sleep 2
mkdir -p src/opt
echo 42 > src/opt/answer.txt

timeout 60 make $MAKE_ARGS > second.out 2>&1 || { cat second.out; exit 1; }
cat second.out
grep -q "^GEN	gen.h$" second.out
test "$(./bin/app)" = "42"

exit 0
