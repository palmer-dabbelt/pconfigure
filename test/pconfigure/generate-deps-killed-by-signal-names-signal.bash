#include "harness_start.bash"

# A GENERATE script that dies on a signal rather than exiting is
# reported as the signal it died on.  wait() encodes that differently
# from an exit -- a script killed by SIGTERM comes back as 15, which
# printed raw reads as "exit 15" -- so the status has to be decoded
# rather than printed, or the one case where the script did not choose
# its own fate is the one that is misreported.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h

BINARIES  += app
SOURCES   += app.c
EOF

cat >src/app.c <<'EOF'
  #include "gen.h"
int main(void) { return 0; }
EOF

# The script kills itself rather than exiting.  The shell pconfigure
# hands the command to runs a lone command by exec'ing it, so the
# signal is what pconfigure's wait() sees, rather than a shell exiting
# with 128 plus the signal on the script's behalf.
cat >src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     kill -TERM $$ ;;
--generate) echo "int x;" ;;
esac
EOF
chmod +x src/gen.h.proc

if $PTEST_BINARY $PCONFIGURE_ARGS >configure.out 2>&1
then
    cat configure.out
    exit 1
fi
cat configure.out

grep -q "^./Configfile:3 'GENERATE += gen.h'$" configure.out
grep -q "error: 'src/gen.h.proc --deps' was killed by signal 15" configure.out
test ! -e Makefile

exit 0
