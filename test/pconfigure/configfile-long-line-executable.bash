#include "harness_start.bash"

# An executable Configfile is a program that prints one, and what it
# prints is read the same way a plain file is.  A generator is exactly
# the thing that produces a long line -- a list of every file it found,
# every define it worked out -- so a long line has to survive coming
# out of a pipe as well as it survives coming out of a file.
mkdir -p src
cat >src/main.c <<'EOF'
#if !defined(GENERATED_1) || !defined(GENERATED_500)
#error a define printed by the executable Configfile went missing
#endif
int main(void) { return 0; }
EOF

cat >Configfile <<'EOF'
#!/bin/bash
echo "LANGUAGES   += c"
echo "BINARIES    += main"
printf "COMPILEOPTS +="
for i in $(seq 1 500)
do
    printf " -DGENERATED_%d" $i
done
printf "\n"
echo "SOURCES     += main.c"
EOF
chmod +x Configfile

$PTEST_BINARY $PCONFIGURE_ARGS
grep -q -- "-DGENERATED_500" Makefile
make $MAKE_ARGS
./bin/main
