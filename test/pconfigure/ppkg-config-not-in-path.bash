#include "harness_start.bash"

# ppkg-config is one of pconfigure's own tools, and the copy that
# matches the pconfigure doing the configuring is the one sitting
# beside it.  Asking $PATH for it instead asks a question about the
# machine: a tree that vendors pconfigure and runs it out of
# src/pconfigure/bin has never installed one, so there is nothing on
# $PATH to find.
#
# Getting that wrong is quiet rather than fatal.  The shell writes
# "ppkg-config: command not found", the backtick expands to the empty
# string, and the Configfile line that asked about a package comes out
# as though it had asked about nothing -- so the build is silently
# configured without the flags the subproject exports.
#
# Every directory holding a ppkg-config is taken off $PATH below, which
# is exactly the state of a machine that has never installed one.  The
# directories are dropped one at a time rather than $PATH being
# emptied, because ppkg-config runs pkg-config and the compiler still
# has to be findable: the point here is that *ppkg-config* is not on
# $PATH, not that nothing is.
scrubbed=()
IFS=: read -ra path_dirs <<<"$PATH"
for dir in "${path_dirs[@]}"
do
    if [[ -x "$dir/ppkg-config" ]]
    then
        continue
    fi

    scrubbed+=("$dir")
done
export PATH="$(IFS=:; echo "${scrubbed[*]}")"

# The premise of everything below.  Checked rather than assumed,
# because a test that silently stopped scrubbing would keep passing
# while testing nothing.
if command -v ppkg-config
then
    echo "ppkg-config is still on PATH, so this test proves nothing" >&2
    exit 1
fi

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
Cflags: -I\${includedir}
EOF

cat >sub/src/sub.h <<EOF
int sub(void);
EOF

cat >sub/src/sub.c <<EOF
int sub(void) { return 7; }
EOF

cat >src/test.c <<EOF
  #include <sub.h>
  #include <stdio.h>
int main(void) { printf("%d\n", sub()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS 2>pconfigure.stderr
cat pconfigure.stderr
cat Makefile

# The symptom, named directly: the shell could not run the backtick.
if grep -q "command not found" pconfigure.stderr
then
    echo "the backtick did not find ppkg-config beside pconfigure" >&2
    exit 1
fi

# ... and the consequence of it, which is what actually breaks a build:
# the flags the subproject exports have to be in the makefile.  "pwd -P"
# because pconfigure asks the kernel where it is, and on macOS that
# resolves the symlink a temporary directory sits behind.
here="$(pwd -P)"
grep -q -- "-I$here/sub/include" Makefile
grep -q -- "-L$here/sub/lib" Makefile

# The flags are not just text: they have to build something.
make $MAKE_ARGS
test "$(./bin/test)" = "7"

exit 0
