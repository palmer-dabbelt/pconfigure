#include "harness_start.bash"

# The reverse of generate-output-under-another-outputs-fragment-name:
# "GENERATE += gen.h.d/inner.h" comes first and makes obj/proc/gen.h.d
# a directory, and only then does "GENERATE += gen.h" ask for the same
# path as its dependency fragment.  The clash is on one of the second
# line's scratch files rather than on its output, so it is that file
# the refusal has to name, and it is still the later of the two lines
# that is refused.

mkdir -p src/gen.h.d

cat >Configfile <<EOF
LANGUAGES += c
GENERATE  += gen.h.d/inner.h
GENERATE  += gen.h
EOF

cat >src/gen.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--generate) echo "#define A 1" ;;
esac
EOF
cat >src/gen.h.d/inner.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--generate) echo "#define B 2" ;;
esac
EOF
chmod +x src/gen.h.proc src/gen.h.d/inner.h.proc

if $PTEST_BINARY $PCONFIGURE_ARGS >configure.out 2>&1
then
    cat configure.out
    exit 1
fi
cat configure.out

head -n1 configure.out | grep -qF "Configfile:3 'GENERATE += gen.h'"
grep -qF "Configfile:2 'GENERATE += gen.h.d/inner.h'" configure.out
grep -qF "'obj/proc/gen.h.d' is the dependency fragment" configure.out

exit 0
