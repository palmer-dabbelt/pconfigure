#include "harness_start.bash"

# The autotools half of the same bug as the kconfig ".config": an
# autotools tree that doesn't install is named from its build
# directory, and "config.status" is the file its configure leaves
# there -- which is also the target of the rule pconfigure writes to
# run that configure.  Naming it as a SUBPROJECT_TARGETS gives the one
# file two recipes, make keeps the one that only checks the file
# exists, configure never runs, and the build fails saying the tree
# didn't produce what it was said to.  The file has a rule already,
# so the line is taken as asking for nothing more than that rule.
mkdir -p sub

cat >sub/configure <<'EOF'
#!/bin/sh
printf 'all:\n\techo built > built\ninstall:\n\ttrue\n' > Makefile
printf '#!/bin/sh\n' > config.status
chmod +x config.status
EOF
chmod +x sub/configure

cat >Configfile <<'EOF'
BUILD_SYSTEMS      += autotools
SUBPROJECTS        += sub
CONFIGUREOPTS      += --no-install
SUBPROJECT_TARGETS += config.status
EOF

$PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1 || { cat configure.out; exit 1; }
cat configure.out

make $MAKE_ARGS > make.out 2>&1 || { cat make.out; exit 1; }
cat make.out
if grep -q "overriding recipe" make.out
then
    exit 1
fi
test -f obj/sub/build/config.status
test -f obj/sub/build/built

exit 0
