#include "harness_start.bash"

# The other order of the same collision: "GENERATE += sub" comes first
# and would write obj/proc/sub as a file, so the "mkdir -p obj/proc/sub"
# for "GENERATE += sub/x.h" fails.  pconfigure used to stop there, but
# it explained the failure as obj/proc not being a directory it could
# write -- sending the reader to check permissions on a directory that
# is fine -- rather than saying the other GENERATE owns that path.

mkdir -p src/sub

cat >Configfile <<EOF
LANGUAGES += c
GENERATE  += sub
GENERATE  += sub/x.h
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

if $PTEST_BINARY $PCONFIGURE_ARGS >configure.out 2>&1
then
    cat configure.out
    exit 1
fi
cat configure.out

# It is the later line that is refused whichever of the two owns the
# directory, and the earlier one is named as what it collides with.
head -n1 configure.out | grep -qF "Configfile:3 'GENERATE += sub/x.h'"
grep -qF "Configfile:2 'GENERATE += sub'" configure.out
grep -qF "needs it to be a directory" configure.out

if grep -q "has to be a directory pconfigure can write" configure.out
then
    exit 1
fi

exit 0
