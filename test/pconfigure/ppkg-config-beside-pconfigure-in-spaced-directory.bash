#include "harness_start.bash"

# The ppkg-config a backtick runs is, by default, the one sitting
# beside the running pconfigure, named by its absolute path, and that
# path has to reach the shell as one word.  It used to be pasted in
# bare, so a pconfigure installed (or vendored) under a directory with
# a space in it, a layout the rest of a plain C build copes with,
# couldn't run its own ppkg-config: the shell ran the first half of
# the path, said "No such file or directory", and the consumer was
# configured without the subproject's flags.  Nothing on the
# Configfile side could have fixed it, since the Configfile only ever
# wrote "ppkg-config".
#
# The tools are copied into such a directory with the libraries
# beside them, which is the layout the binaries' $ORIGIN runpath
# expects.
here_bin="$(dirname "$PTEST_BINARY")"
mkdir -p "my tools/bin" "my tools/lib"
cp "$here_bin"/* "my tools/bin/"
cp "$here_bin"/../lib/*.so "my tools/lib/"
pconfigure="$(pwd)/my tools/bin/pconfigure"
test -x "$pconfigure"

mkdir -p src sub/src

cat >Configfile <<EOF
SUBPROJECTS += sub

LANGUAGES   += c

BINARIES    += test
COMPILEOPTS += \`ppkg-config sub --cflags\`
LINKOPTS    += \`ppkg-config sub --libs\`
SOURCES     += test.c
EOF

cat >sub/Configfile <<EOF
LANGUAGES += c
LANGUAGES += pkgconfig

LIBRARIES += libsub.so
SOURCES   += sub.c

LIBRARIES += pkgconfig/sub.pc
SOURCES   += sub.pc
EOF

cat >sub/src/sub.pc <<EOF
prefix=@@pconfigure_prefix@@
libdir=\${prefix}/@@pconfigure_libdir@@

Name: sub
Description: a subproject
Version: 1.0
Libs: -L\${libdir} -lsub
Cflags: -DSUB_ANSWER=7
EOF

cat >sub/src/sub.c <<EOF
int sub(void) { return 7; }
EOF

cat >src/test.c <<EOF
#include <stdio.h>
int sub(void);
int main(void) { printf("%d\n", sub() + SUB_ANSWER); return 0; }
EOF

"$pconfigure" $PCONFIGURE_ARGS 2>stderr
cat stderr
cat Makefile

if grep -q "No such file" stderr
then
    exit 1
fi
grep -q -- "-DSUB_ANSWER=7" Makefile

make $MAKE_ARGS
test "$(./bin/test)" = "14"

exit 0
