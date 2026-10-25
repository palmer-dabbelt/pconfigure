#include "harness_start.bash"

# A GENERATE in a subproject whose "--deps" fails.  The error tells the
# reader to run the script by hand, and a subproject is where that is
# easy to get wrong: the script is found at "sub/src/gen.h.proc" from
# where pconfigure was run, but it is run as "src/gen.h.proc" from
# inside "sub/", and an instruction that mixed the two named a file
# that isn't there from where it said to stand.

mkdir -p sub/src

cat >Configfile <<EOF
SUBPROJECTS += sub
EOF

cat >sub/Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h

BINARIES  += app
SOURCES   += app.c
EOF

cat >sub/src/app.c <<'EOF'
  #include "gen.h"
int main(void) { return 0; }
EOF

# The script only fails the way it is meant to when it is run from the
# top of its own project, so that an instruction which ran it from
# anywhere else would not reproduce the failure the reader is being
# sent to look at.
cat >sub/src/gen.h.proc <<'EOF'
#!/bin/bash
test -f src/gen.h.proc || exit 9
case "$1" in
--deps)     exit 4 ;;
--generate) echo "int x;" ;;
esac
EOF
chmod +x sub/src/gen.h.proc

if $PTEST_BINARY $PCONFIGURE_ARGS >configure.out 2>&1
then
    cat configure.out
    exit 1
fi
cat configure.out

# It names the subproject's Configfile line, and the script as it is
# spelled from here, which is where the reader will go looking for it.
grep -q "^sub/Configfile:3 'GENERATE += gen.h'$" configure.out
grep -q "error: 'sub/src/gen.h.proc --deps' exited with status 4$" configure.out

# The command it says to run is the one that was actually run, cd and
# all.
grep -q ": cd sub/ && src/gen.h.proc --deps$" configure.out

# And following it to the letter reaches the script and gets the same
# failure back, rather than "No such file or directory".
by_hand="$(sed -n 's/^  run it by hand.*the script: //p' configure.out)"
test -n "$by_hand"
set +e
(eval "$by_hand")
status=$?
set -e
test "$status" = 4

exit 0
