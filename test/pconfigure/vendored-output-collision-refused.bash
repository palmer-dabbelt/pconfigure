#include "harness_start.bash"

# A vendored tree builds into the object directory under its own name
# with the source directory taken off the front, so "src/tool" and
# "tool" both ask for "obj/tool".  Two trees sharing an output
# directory would each run its build system over the other one's
# files, so the second line is refused, naming both trees and the line
# that asked second.
mkdir -p src/tool tool

cat >Configfile <<EOF
BUILD_SYSTEMS += kconfig

SUBPROJECTS   += src/tool
SUBPROJECTS   += tool
EOF

for d in src/tool tool
do
    printf 'config X\n\tbool "x"\n' > $d/Kconfig
    echo "all:" > $d/Makefile
done

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    exit 1
fi
cat out
grep -q "Configfile:4 'SUBPROJECTS += tool'" out
grep -q "this builds into 'obj/tool', and so does 'src/tool'" out
test ! -e Makefile

# A tree vendored somewhere other than the source directory keeps the
# path it was vendored at, so "vendor/tool" is "obj/vendor/tool" and
# sits beside "src/tool" without a word.
rm -rf tool
mkdir -p vendor/tool
printf 'config X\n\tbool "x"\n' > vendor/tool/Kconfig
echo "all:" > vendor/tool/Makefile

cat >Configfile <<EOF
BUILD_SYSTEMS += kconfig

SUBPROJECTS   += src/tool
SUBPROJECTS   += vendor/tool
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
grep -q "obj/tool/" Makefile
grep -q "obj/vendor/tool/" Makefile

exit 0
