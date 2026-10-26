#include "harness_start.bash"

# A package asked for with a version constraint, the way pkg-config
# takes one: "sub >= 1.0" as one quoted argument.  ppkg-config hands
# it on to pkg-config, and --have adds the define when the constraint
# holds.  With --optional, a constraint the build tree's package
# doesn't meet gives no flags and no define, rather than a failure.
# The package's Cflags carry a define of their own so that "no flags"
# can be seen: the unmet request is the only thing compiling "nosub",
# so SUB_CFLAGS reaching it would mean the constraint was ignored.
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
Cflags: -I\${includedir} -DSUB_CFLAGS
EOF

cat >sub/src/sub.h <<EOF
int sub(void);
EOF

cat >sub/src/sub.c <<EOF
int sub(void) { return 7; }
EOF

cat >Configfile <<EOF
SUBPROJECTS += sub

LANGUAGES   += c

BINARIES    += test
COMPILEOPTS += \`ppkg-config --have SUB "sub >= 1.0" --cflags\`
LINKOPTS    += \`ppkg-config sub --libs\`
SOURCES     += test.c

BINARIES    += nosub
COMPILEOPTS += \`ppkg-config --optional --have SUB2 "sub >= 2.0" --cflags\`
SOURCES     += nosub.c
EOF

cat >src/test.c <<'EOF'
#include <sub.h>
#include <stdio.h>
#ifndef HAVE_SUB
#error HAVE_SUB should be defined: sub 1.0 is at least 1.0
#endif
#ifndef SUB_CFLAGS
#error the met constraint should have given sub's own flags
#endif
int main(void) { printf("%d\n", sub()); return 0; }
EOF

cat >src/nosub.c <<'EOF'
#include <stdio.h>
#ifdef HAVE_SUB2
#error HAVE_SUB2 should not be defined: sub 1.0 is older than 2.0
#endif
#ifdef SUB_CFLAGS
#error the unmet constraint should have given no flags at all
#endif
int main(void) { printf("none\n"); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
grep -qE -- "-DHAVE_SUB( |$)" Makefile
if grep -q -- "-DHAVE_SUB2" Makefile
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/test)" = "7"
test "$(./bin/nosub)" = "none"

exit 0
