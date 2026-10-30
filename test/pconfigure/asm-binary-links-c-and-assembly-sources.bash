test "$(uname -s)" == "Darwin" && exit 0
#include "harness_start.bash"

# The manual's 'asm' is C that also compiles '*.S', and links the way
# C does.  The reason anybody writes it down is a program that is
# mostly C with a little assembly in it -- a start file, a context
# switch -- so the one target here names a source of each, and the
# program has to come out of the one link with the C calling into the
# assembly.
#
# The '.S' is the preprocessed spelling of assembly, which is why the
# instructions sit under an #if: the same file has to assemble on
# whichever machine runs the test.  Each arm also marks its stack as
# not executable: an object without that note asks for an executable
# stack, which ld warns about and a binutils built with
# --enable-error-execstack refuses, so leaving it out would make this
# test's result depend on how the host's linker was configured.  ARM
# spells the section type with '%' because '@' starts a comment there.

mkdir -p src
cat >src/main.c <<'EOF2'
int answer(void);
int main(void) { return answer() == 42 ? 0 : 1; }
EOF2
cat >src/answer.S <<'EOF2'
	.text
	.globl answer
answer:
#if defined(__x86_64__)
	movl $42, %eax
	ret
	.section .note.GNU-stack,"",@progbits
#elif defined(__aarch64__)
	mov w0, #42
	ret
	.section .note.GNU-stack,"",%progbits
#elif defined(__riscv)
	li a0, 42
	ret
	.section .note.GNU-stack,"",@progbits
#else
#error "no assembly here for this machine"
#endif
EOF2

cat >Configfile <<'EOF2'
LANGUAGES += c
LANGUAGES += asm

BINARIES  += main
SOURCES   += main.c
SOURCES   += answer.S
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# Neither source may be handed to the compiler as the other's
# language: C's "-x c" on the '.S' reads the first directive as C and
# fails, and a C file assembled fails just as loudly.
if grep -- "-x c .*src/answer\.S" Makefile
then
    exit 1
fi

make $MAKE_ARGS
./bin/main
