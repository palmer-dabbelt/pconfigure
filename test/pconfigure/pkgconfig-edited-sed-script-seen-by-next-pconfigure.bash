#include "harness_start.bash"

# A subproject's .pc can be passed through a sed script named by a
# "-S" compile option, which makes that script as much a source of
# the build-tree copy as the .pc itself.  Editing the script and
# rerunning pconfigure has to answer the consumer's ppkg-config out
# of the edited script, the same as editing the .pc would: a copy
# left over from the last configure, written by the old script, is
# not the answer any more.
mkdir -p src sub/src

cat >sub/Configfile <<EOF
LANGUAGES += c
LANGUAGES += h
LANGUAGES += pkgconfig

HEADERSRC += sub.h

LIBRARIES += libsub.so
SOURCES   += sub.c

LIBRARIES   += pkgconfig/sub.pc
COMPILEOPTS += -Ssrc/answer.sed
SOURCES     += sub.pc
EOF

cat >sub/src/answer.sed <<EOF
s/@@answer@@/9/
EOF

cat >sub/src/sub.pc <<EOF
prefix=@@pconfigure_prefix@@
libdir=\${prefix}/@@pconfigure_libdir@@
includedir=\${prefix}/@@pconfigure_hdrdir@@

Name: sub
Description: a subproject
Version: 1.0
Libs: -L\${libdir} -lsub
Cflags: -I\${includedir} -DANSWER=@@answer@@
EOF

cat >sub/src/sub.h <<EOF
int sub(void);
EOF

cat >sub/src/sub.c <<EOF
int sub(void) { return 7; }
EOF

cat >src/app.c <<EOF
#include <sub.h>
#include <stdio.h>
int main(void) { printf("%d\\n", sub() + ANSWER); return 0; }
EOF

cat >Configfile <<EOF
SUBPROJECTS += sub

LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += \`ppkg-config sub --cflags\`
LINKOPTS    += \`ppkg-config sub --libs\`
SOURCES     += app.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "16"

# Only the script changes; the .pc it's applied to stays as it was.
sleep 1
cat >sub/src/answer.sed <<EOF
s/@@answer@@/13/
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat sub/obj/pkgconfig/sub.pc

grep -q -- "-DANSWER=13" sub/obj/pkgconfig/sub.pc
grep -q -- "-DANSWER=13" Makefile
if grep -q -- "-DANSWER=9" Makefile
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/app)" = "20"

exit 0
