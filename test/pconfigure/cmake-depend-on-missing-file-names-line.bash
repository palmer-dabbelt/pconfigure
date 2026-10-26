#include "harness_start.bash"

# A --depend can only be looked for once every SUBPROJECTS in the
# project has been read, since it may name a tree further down.  By
# then reading has moved on, and with two --depend lines the path
# alone is the only thing that says which one is wrong -- so the
# refusal names the line that wrote it, the same as a refusal made
# while that line was being read.
mkdir -p one two
echo 'project(one NONE)' > one/CMakeLists.txt
echo 'project(two NONE)' > two/CMakeLists.txt
touch present.txt

cat >Configfile <<'EOF'
BUILD_SYSTEMS += cmake

SUBPROJECTS   += one
CONFIGUREOPTS += --depend present.txt

SUBPROJECTS   += two
CONFIGUREOPTS += --depend absent.txt
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    exit 1
fi
cat out
grep -q "'--depend absent.txt' names 'absent.txt', which is neither" out
grep -q "Configfile:7 'CONFIGUREOPTS += --depend absent.txt'" out

exit 0
