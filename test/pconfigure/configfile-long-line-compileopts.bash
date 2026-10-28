#include "harness_start.bash"

# A Configfile line is as long as its author made it.  A project that
# hands a long list of defines to one COMPILEOPTS line -- or gets one
# out of a generator -- means one command, however many bytes it
# takes, and every define on it has to reach the compiler.  Nothing in
# the manual puts a limit on how long a line may be, so a line that is
# cut short somewhere is a line that silently means something else.
mkdir -p src
defines=""
for i in $(seq 1 400)
do
    defines="$defines -DDEFINE_NUMBER_$i"
done

cat >Configfile <<EOF
LANGUAGES   += c

BINARIES    += main
COMPILEOPTS += $defines -DLAST_ONE=1
SOURCES     += main.c
EOF

# The line above is past twice the 2048 bytes a line used to be cut
# at, which is the point: it would have come back in three pieces.
test $(sed -n 4p Configfile | wc -c | tr -d ' ') -gt 4096

cat >src/main.c <<'EOF'
#if !defined(DEFINE_NUMBER_1) || !defined(DEFINE_NUMBER_400) || !defined(LAST_ONE)
#error a define from the long COMPILEOPTS line went missing
#endif
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
grep -q -- "-DDEFINE_NUMBER_400 -DLAST_ONE=1" Makefile
make $MAKE_ARGS
./bin/main
