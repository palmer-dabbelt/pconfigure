#include "harness_start.bash"

# The manual's own example of ppkg-config: "--optional --have NAME"
# turns "is this package installed" into a -DHAVE_NAME, so that a
# Configfile can switch code on what the machine has.  Pinned down
# here against a pkg-config whose answer is known: a package that is
# there gives its flags plus the define, one that isn't gives nothing
# at all and still exits 0, and the same question without --optional
# is a failure.
ppkg="$(dirname "$PTEST_BINARY")/ppkg-config"
test -x "$ppkg"

mkdir fakebin
cat >fakebin/pkg-config <<'EOF'
#!/bin/bash
for arg in "$@"
do
    if [[ "$arg" == "present" ]]
    then
        echo "-I/opt/present/include"
        exit 0
    fi
done
exit 1
EOF
chmod +x fakebin/pkg-config
export PATH="$(pwd)/fakebin:$PATH"

"$ppkg" --optional --have PRESENT present --cflags >present.out
cat present.out
test "$(cat present.out)" = "-I/opt/present/include -DHAVE_PRESENT"

"$ppkg" --optional --have ABSENT absent --cflags >absent.out
cat absent.out
test "$(cat absent.out)" = ""

# Without --optional the missing package is a failure, and no define
# is invented for it either way.
set +e
"$ppkg" --have ABSENT absent --cflags >required.out
status="$?"
set -e
test "$status" != "0"
if grep -q "HAVE_ABSENT" required.out
then
    exit 1
fi

# And end to end, the define is something the compiled code can see.
mkdir -p src
cat >Configfile <<EOF
LANGUAGES   += c

BINARIES    += test
COMPILEOPTS += \`ppkg-config --optional --have PRESENT present --cflags\`
COMPILEOPTS += \`ppkg-config --optional --have ABSENT absent --cflags\`
SOURCES     += test.c
EOF

cat >src/test.c <<EOF
#include <stdio.h>
int main(void)
{
#ifdef HAVE_PRESENT
    printf("present");
#endif
#ifdef HAVE_ABSENT
    printf("absent");
#endif
    printf("\n");
    return 0;
}
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/test)" = "present"

exit 0
