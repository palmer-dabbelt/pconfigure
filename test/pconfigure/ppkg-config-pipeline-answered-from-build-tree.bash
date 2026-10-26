#include "harness_start.bash"

# A backtick that runs ppkg-config and filters what it says -- here,
# dropping a define the project doesn't want with a sed -- is still
# answered out of the build tree: the PKG_CONFIG_PATH pconfigure gives
# the command reaches the ppkg-config at the head of the pipeline, and
# the filter only sees its output.  Whether that PKG_CONFIG_PATH is a
# prefix on the first command or exported to the whole pipeline is
# pconfigure's business; either way the package has to be found.
mkdir -p src sub/src

cat >sub/Configfile <<EOF
LANGUAGES += c
LANGUAGES += h
LANGUAGES += pkgconfig

HEADERSRC += sub.h

LIBRARIES += libsub.so
SOURCES   += sub.c

LIBRARIES += pkgconfig/sub.pc
SOURCES   += sub.pc
EOF

cat >sub/src/sub.pc <<EOF
prefix=@@pconfigure_prefix@@
libdir=\${prefix}/@@pconfigure_libdir@@
includedir=\${prefix}/@@pconfigure_hdrdir@@

Name: sub
Description: a subproject
Version: 1.0
Libs: -L\${libdir} -lsub
Cflags: -I\${includedir} -DUNWANTED_BY_TOP=1
EOF

cat >sub/src/sub.h <<EOF
int sub(void);
EOF

cat >sub/src/sub.c <<EOF
int sub(void) { return 7; }
EOF

# The filter's work is checked by the compiler rather than by reading
# the Makefile, whose text may also carry the backtick's own sed script
# and so name the define either way.
cat >src/test.c <<'EOF'
#include <sub.h>
#include <stdio.h>
#ifdef UNWANTED_BY_TOP
#error the sed at the end of the pipeline should have dropped this
#endif
int main(void) { printf("%d\n", sub()); return 0; }
EOF

cat >Configfile <<EOF
SUBPROJECTS += sub

LANGUAGES   += c

BINARIES    += test
COMPILEOPTS += \`ppkg-config sub --cflags | sed 's/-DUNWANTED_BY_TOP=1//'\`
LINKOPTS    += \`ppkg-config sub --libs\`
SOURCES     += test.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS

# The build tree's include directory is what the head of the pipeline
# answered with; nothing else in the test could have named it.
here="$(pwd -P)"
grep -q -- "-I$here/sub/include" Makefile

make $MAKE_ARGS
test "$(./bin/test)" = "7"

exit 0
