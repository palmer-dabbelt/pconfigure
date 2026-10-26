#include "harness_start.bash"

# BASH doesn't put the generated-files directory on its include path
# the way C does, but the manual says its #include scan searches the
# -I directories in COMPILEOPTS the way pbashc does, so a script can
# include a GENERATE output by naming obj/proc there.  This pins that
# the generated file is then a prerequisite of the script: the script
# is rebuilt when the generator's input changes, and a parallel build
# from clean generates before it compiles.

mkdir -p src

echo 1 > src/in.txt

cat >src/gen.bash.proc <<'EOF'
#!/bin/sh
case "$1" in
--deps)     echo "src/in.txt" ;;
--generate) echo "V=$(cat src/in.txt)" ;;
esac
EOF
chmod +x src/gen.bash.proc

cat >src/tool.bash <<'EOF'
#include "gen.bash"
echo "$V"
EOF

cat >Configfile <<EOF
LANGUAGES   += bash
GENERATE    += gen.bash
BINARIES    += tool
COMPILEOPTS += -Iobj/proc
SOURCES     += tool.bash
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
grep -q "^bin/tool: .*obj/proc/gen.bash" Makefile
make $MAKE_ARGS
test "$(./bin/tool)" = "1"

sleep 2
echo 2 > src/in.txt
make $MAKE_ARGS
test "$(./bin/tool)" = "2"

make $MAKE_ARGS clean
make $MAKE_ARGS -j2
test "$(./bin/tool)" = "2"

exit 0
