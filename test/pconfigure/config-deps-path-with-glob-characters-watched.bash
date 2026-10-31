#include "harness_start.bash"

# The other characters a CONFIG_DEPS name can carry that mean something
# to the glob "$(wildcard ...)" reads it with.  A '*' and a '?' have to
# find the file they are in and nothing else, which is what the two
# decoys are for: quoted badly, each name matches its decoy as well as
# itself and an edit to the decoy reconfigures.  A ']' with no '[' is
# not special, and has to stay that way however the rest are quoted.

mkdir -p src

cat >Configfile <<'EOC'
AUTORECONFIGURE  = true
CONFIG_DEPS     += star*1.txt
CONFIG_DEPS     += what?1.txt
CONFIG_DEPS     += close]1.txt
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
EOC

echo 'int main(void) { return 0; }' > src/main.c
echo 1 > 'star*1.txt'
echo 1 > 'what?1.txt'
echo 1 > 'close]1.txt'
echo 1 > 'starx1.txt'
echo 1 > 'whatx1.txt'

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS > first.log 2>&1 || { cat first.log; exit 1; }
cat first.log

make $MAKE_ARGS > settled.log 2>&1 || { cat settled.log; exit 1; }
cat settled.log
if grep -q PCONFIGURE settled.log
then
    exit 1
fi

# The decoys are nothing to do with this build.
sleep 1
echo 2 > 'starx1.txt'
echo 2 > 'whatx1.txt'
make $MAKE_ARGS > decoys.log 2>&1 || { cat decoys.log; exit 1; }
cat decoys.log
if grep -q PCONFIGURE decoys.log
then
    exit 1
fi

# And an edit to each of the real ones is noticed.
for name in 'star*1.txt' 'what?1.txt' 'close]1.txt'
do
    sleep 1
    echo 2 > "$name"
    make $MAKE_ARGS > edited.log 2>&1 || { cat edited.log; exit 1; }
    cat edited.log
    grep -q PCONFIGURE edited.log
done
