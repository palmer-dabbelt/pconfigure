#include "harness_start.bash"

# The same as configfile-failing-backtick-names-line.bash, for the
# other way a backticked command goes wrong: it isn't installed at all.
# The shell says "command not found" and pconfigure used to add the
# wait status ("32512") -- a number that means "exit 127" to nobody
# reading it -- without saying which Configfile line ran the command.
# The command is on the second line of a CONFIG rather than of the
# Configfile itself, so the message has to name the right file as well
# as the right number.
mkdir -p src Configfiles
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfile <<'END'
LANGUAGES   += c
BINARIES    += main
CONFIG      += flags
SOURCES     += main.c
END

cat >Configfiles/flags <<'END'
# What a missing pkg-config looks like.
COMPILEOPTS += `pconfigure-test-no-such-command --cflags`
END

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    exit 1
fi
cat out
test ! -e Makefile
grep -q "pconfigure-test-no-such-command" out
grep -q "Configfiles/flags:2" out
grep -q "127" out
if grep -q "32512" out
then
    echo "reported the wait status, not the exit status" >&2
    exit 1
fi
