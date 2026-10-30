test "$(uname -s)" == "Darwin" && exit 0
#include "harness_start.bash"

# A test can be written in assembly too, and its check target comes
# from languages/cxx.c++ because 'asm' is one of the C-like languages
# that file implements.  check-c-test-in-project-path-with-space.bash
# is the C half of this; this is the one that would notice 'asm'
# being given a check target of its own that the C ones don't share.
#
# The assembly marks its stack as not executable for the reason
# asm-binary-links-c-and-assembly-sources.bash gives: without it the
# link fails on a host whose ld refuses an executable stack.

mkdir -p src test/main

echo 'int main(void) { return 0; }' > src/main.c
cat >test/main/t.S <<'EOF2'
	.text
	.globl main
main:
#if defined(__x86_64__)
	xorl %eax, %eax
	ret
	.section .note.GNU-stack,"",@progbits
#elif defined(__aarch64__)
	mov w0, #0
	ret
	.section .note.GNU-stack,"",%progbits
#elif defined(__riscv)
	li a0, 0
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
TESTSRC   += t.S
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS check

test "$(tar -xOf check/main/t.S ptest__return)" = 0
