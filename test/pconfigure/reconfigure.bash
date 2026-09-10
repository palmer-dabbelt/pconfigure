#include "harness_start.bash"

# What a Makefile says is what the Configfiles said the last time
# somebody ran pconfigure.  Nothing in a build changes that on its
# own, which leaves the question of how you ask -- and "run the
# configure script again" is a thing every build system in the world
# spells differently.  This one spells it "make reconfigure".

# The one being tested, rather than whatever is installed on this
# machine: the rule runs whatever the PATH says "pconfigure" is, so
# the PATH is what has to be pointed at it.
export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

BINARIES  += first
SOURCES   += first.c
EOF

for b in first second third
do
    echo "int main(void) { return 0; }" > "src/$b.c"
done

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test -e bin/first

##############################################################################
# A Configfile that changed                                                  #
##############################################################################
# Nothing has run pconfigure since, so nothing knows about it.  This
# is the behaviour being kept rather than one being fixed: a build
# that reconfigured itself would be deciding, on its own, to throw
# away and rebuild whatever the new options touched.
cat >>Configfile <<EOF

BINARIES  += second
SOURCES   += second.c
EOF

make $MAKE_ARGS
test ! -e bin/second
if grep -q "second" Makefile
then
    exit 1
fi

##############################################################################
# Asking                                                                     #
##############################################################################
make $MAKE_ARGS reconfigure > out 2>&1
cat out
grep -q "^PCONFIGURE$" out
grep -q "^bin/second:" Makefile

make $MAKE_ARGS
test -e bin/second

##############################################################################
# Asking for something in particular                                         #
##############################################################################
# The rule takes the options pconfigure would have taken, so a tree
# that is normally configured with an extra Configfile can say so
# without going around the rule.
mkdir -p Configfiles
cat >Configfiles/extra <<EOF
LANGUAGES += c

BINARIES  += third
SOURCES   += third.c
EOF

make $MAKE_ARGS reconfigure PCONFIGURE_ARGS="--config extra"
grep -q "^bin/third:" Makefile

make $MAKE_ARGS
test -e bin/third

# And with the options left off again it goes back to what the
# Configfile alone says, since that is all pconfigure was told.
make $MAKE_ARGS reconfigure
if grep -q "^bin/third:" Makefile
then
    exit 1
fi

exit 0
