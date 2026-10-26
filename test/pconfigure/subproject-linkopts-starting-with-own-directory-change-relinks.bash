#include "harness_start.bash"

# A link's directory is named by a hash of its options as the
# subproject would spell them, the same way an object's name is.  The
# LINKOPTS go into that hash as the subproject wrote them, before they
# are rooted at the subproject, so they are already spelled that way
# and have nothing to take off.  Taking the subproject's directory off
# them anyway took off a part of the path the subproject actually
# wrote: "-Lsub/pre" (its own sub/pre directory, sub/sub/pre from the
# top) hashed the same as "-Lpre" (sub/pre), and switching from one to
# the other kept the program linked against the first.
mkdir -p sub/src
cat >Configfile <<'EOT'
SUBPROJECTS += sub
EOT
cat >sub/Configfile <<'EOT'
LANGUAGES   += c
BINARIES    += app
LINKOPTS    += -Lsub/pre
LINKOPTS    += -lvalue
SOURCES     += main.c
EOT
cat >sub/src/main.c <<'EOT'
int value(void);
int main(void) { return value(); }
EOT

# Two prebuilt archives that answer differently: 1 from the one the
# first LINKOPTS finds, 2 from the one the second does.
n=0
for d in sub/sub/pre sub/pre
do
    n=$((n + 1))
    mkdir -p $d
    echo "int value(void) { return $n; }" > $d/value.c
    ${CC:-cc} -c $d/value.c -o $d/value.o
    ${AR:-ar} rcs $d/libvalue.a $d/value.o
done

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
set +e
./sub/bin/app
got=$?
set -e
test "$got" = 1

sed -i 's@-Lsub/pre@-Lpre@' sub/Configfile
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
set +e
./sub/bin/app
got=$?
set -e
test "$got" = 2
