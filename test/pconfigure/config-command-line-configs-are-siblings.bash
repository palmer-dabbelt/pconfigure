#include "harness_start.bash"

# Each "--config" on a command line stands beside the others, the way a
# run of "CONFIG +=" lines at the top of a Configfile would, so one of
# them naming a file that another also names is not a cycle.  The
# CONFIGs a file asks for used to be read after each of its lines,
# which left a second "--config" waiting in the same queue to be read
# from inside the first one's file -- and once pconfigure refused a
# file named from inside itself, "--config debugsym --config debug"
# with a debug that CONFIGs debugsym was taken for exactly that, and
# refused with a message about a loop that wasn't there.
mkdir -p src Configfiles
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfiles/debugsym <<'EOF2'
LANGUAGES   += c
COMPILEOPTS += -g
EOF2

cat >Configfiles/debug <<'EOF2'
CONFIG      += debugsym
LANGUAGES   += c
COMPILEOPTS += -DDEBUG
EOF2

cat >Configfile <<'EOF2'
LANGUAGES   += c
BINARIES    += main
SOURCES     += main.c
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS --config debugsym --config debug >out 2>&1
cat out
if grep -q "already being read" out
then
    echo "two --config options were taken for a cycle" >&2
    exit 1
fi
# debug's CONFIG does read debugsym a second time, though, so that is
# said about at the CONFIG that did it, naming the "--config" that read
# the file first.
grep -q "Configfiles/debug:1 'CONFIG += debugsym'" out
grep -q "warning: .*Configfiles/debugsym.* was already read for args:1 '--config debugsym'" out
make $MAKE_ARGS
./bin/main

# The same name twice is no more a cycle than two different ones.
rm -f Makefile
$PTEST_BINARY $PCONFIGURE_ARGS --config debug --config debug >out 2>&1
cat out
if grep -q "already being read" out
then
    echo "a --config given twice was taken for a cycle" >&2
    exit 1
fi
test -e Makefile

# It is a repeat, said about once at the second "--config".  The CONFIG
# inside debug is read again only because debug is, and the first
# reading of debugsym was that very line; complaining about it too
# would blame the line as a repeat of itself.
grep -q "args:3 '--config debug'" out
grep -q "warning: .*Configfiles/debug, .* was already read for args:1 '--config debug'" out
test "$(grep -c "was already read" out)" = 1
