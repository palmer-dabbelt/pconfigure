#include "harness_start.bash"

# A subproject's "-L dir" is written from the subproject's directory,
# and is rooted there whether it is spelled as one word or as two.
# The two-word spelling is the easy one to lose: the directory is a
# word of its own, so rooting it means remembering that the word
# before it was a bare "-L".
#
# The library is prebuilt and sits in the subproject's own "ext", so
# the only way to find it is a "-L" that was rooted.

mkdir -p a/src a/ext

cat >a/ext/ext.c <<'EOF'
int ext(void) { return 5; }
EOF
${CC:-cc} -shared -fPIC -o a/ext/libext.so a/ext/ext.c

cat >Configfile <<EOF
SUBPROJECTS += a
EOF

cat >a/Configfile <<EOF
LANGUAGES += c

BINARIES  += app
LINKOPTS  += -L ext -lext
LINKOPTS  += -Wl,-rpath,$(pwd)/a/ext
SOURCES   += main.c
EOF

cat >a/src/main.c <<'EOF'
#include <stdio.h>
int ext(void);
int main(void) { printf("%d\n", ext()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
cat a/obj/Makefile.a
# Spelled through the variable that stands for the subproject's
# directory, which is how every path in its Makefile is rooted.
grep -qF -- '-L $(pconfigure_subdir_a)ext' a/obj/Makefile.a

make $MAKE_ARGS
test "$(./a/bin/app)" = "5"
