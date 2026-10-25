#include "harness_start.bash"

# A CONFIG that names a file which doesn't exist is refused
# (config-missing-file-refused.bash), and config_lines() asks about
# existence rather than readability so that a file which is there but
# can't be read is complained about by whatever reads it.  Nothing
# used to: a file that couldn't be opened was read as no lines, and
# the Makefile came out missing everything it declared -- exactly the
# outcome the missing-file refusal exists to prevent.
#
# Root reads a file with no read permission, so there is nothing to
# test there.
if test "$(id -u)" = 0
then
    echo "SKIP: root can read a file with no read permission"
    exit 0
fi

mkdir -p src Configfiles
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfile <<'END'
LANGUAGES += c
CONFIG    += program
END

cat >Configfiles/program <<'END'
BINARIES  += main
SOURCES   += main.c
END
chmod 000 Configfiles/program

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    chmod 644 Configfiles/program
    cat out
    exit 1
fi
chmod 644 Configfiles/program
cat out
test ! -e Makefile
grep -q "Configfile:2 .CONFIG += program." out
grep -q "Configfiles/program can.t be read" out

# A --config is documented as exactly a CONFIG, so the same file asked
# for from the command line is refused the same way, pointing at the
# option since there is no Configfile line to point at.
cat >Configfile <<'END'
LANGUAGES += c
END
chmod 000 Configfiles/program

if $PTEST_BINARY $PCONFIGURE_ARGS --config program >out 2>&1
then
    chmod 644 Configfiles/program
    cat out
    exit 1
fi
chmod 644 Configfiles/program
cat out
test ! -e Makefile
grep -q "args:1 .--config." out
grep -q "Configfiles/program can.t be read" out
