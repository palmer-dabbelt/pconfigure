#include "harness_start.bash"

# The build-tree copy of a subproject's .pc is what a ppkg-config
# backtick above it is answered out of, and pconfigure writes that
# copy itself while it reads the Configfile.  It used to do so only
# when there wasn't one yet, so a copy left over from the last
# configure was believed however much older than its source it was.
#
# The sequence somebody would naturally use after editing the
# subproject's .pc -- run pconfigure again, then make -- then
# configured the consumer out of yesterday's .pc.  make rebuilt the
# copy afterwards, but with AUTORECONFIGURE off nothing acts on that,
# and the consumer was built without the flag the .pc now exports.
# Rerunning pconfigure is exactly the step that has to pick it up.
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
Cflags: -I\${includedir} -DANSWER=9
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

# The subproject changes the flag it exports, and the consumer is
# reconfigured the ordinary way.  The pause keeps the edit out of the
# second the first build happened in, so that what's being tested is
# pconfigure and not the resolution of make's clock.
sleep 1
sed -i.bak 's/-DANSWER=9/-DANSWER=13/' sub/src/sub.pc

$PTEST_BINARY $PCONFIGURE_ARGS
cat sub/obj/pkgconfig/sub.pc

# The configure that ran after the edit is the one that has to have
# seen it: in the copy, and in the consumer's compile flags.
grep -q -- "-DANSWER=13" sub/obj/pkgconfig/sub.pc
grep -q -- "-DANSWER=13" Makefile
if grep -q -- "-DANSWER=9" Makefile
then
    exit 1
fi

# And so one make is all it takes.  7 + 13 = 20.
make $MAKE_ARGS
test "$(./bin/app)" = "20"

exit 0
