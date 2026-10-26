#include "harness_start.bash"

# Every GENERATE output lands in the one obj/proc directory, so two
# names can collide by more than being equal: "GENERATE += sub/x.h"
# makes obj/proc/sub a directory, and "GENERATE += sub" wants the very
# same path to be a file.  Both can't be had.
#
# Written in this order the output of the second line used never to be
# made at all.  Its script only runs when the output isn't there, and a
# directory is there, so make took obj/proc/sub as up to date, the
# build went green and src/sub.proc never ran.  The second line is
# refused instead, naming the first, the way two outputs that share a
# scratch file are.

mkdir -p src/sub

cat >Configfile <<EOF
LANGUAGES += c
GENERATE  += sub/x.h
GENERATE  += sub
BINARIES  += app
SOURCES   += app.c
EOF

cat >src/sub.proc <<'EOF'
#!/bin/sh
case "$1" in
--generate) echo "sub ran" ;;
esac
EOF
cat >src/sub/x.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--generate) echo "#define V 2" ;;
esac
EOF
chmod +x src/sub.proc src/sub/x.h.proc

cat >src/app.c <<'EOF'
#include "sub/x.h"
int main(void) { return V - 2; }
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS >configure.out 2>&1
then
    cat configure.out
    exit 1
fi
cat configure.out

# The refused line comes first and the line it collides with after it,
# along with the path the two disagree about.
head -n1 configure.out | grep -qF "Configfile:3 'GENERATE += sub'"
grep -qF "Configfile:2 'GENERATE += sub/x.h'" configure.out
grep -qF "'obj/proc/sub'" configure.out
grep -qF "needs it to be a directory" configure.out

# Refused before the second script ran: obj/proc/sub may well be the
# first line's directory by now, but it is not the second line's file.
test ! -f obj/proc/sub

exit 0
