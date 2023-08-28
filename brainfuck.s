    .globl _start
    .text

CHUNK_SIZE = 512

_start:
    movq %rsp, %rbp
    subq $16, %rsp
    # rbp-0 = input memory ptr
    # rbp-8 = input memory len

    # mmap(addr=0, len=CHUNK_SIZE, prot=READ|WRITE, flags=PRIVATE|ANONYMOUS, fildes=-1, off=0)
    movq          $9, %rax
    movq          $0, %rdi
    movq $CHUNK_SIZE, %rsi
    movq       $0x03, %rdx
    movq       $0x22, %r10
    movq         $-1, %r8
    movq          $0, %r9
    syscall
    movq        %rax, (%rbp)

    # read(stdin, buf, count=512)
    xorq        %rax, %rax
    xorq        %rdi, %rdi
    movq      (%rbp), %rsi
    movq $CHUNK_SIZE, %rdx
    syscall
    movq        %rax, -8(%rbp)

    # mremap(buf, old_len=CHUNK_SIZE, new_len=1024, flags=MAYMOVE)
    movq         $25, %rax
    movq      (%rbp), %rdi
    movq $CHUNK_SIZE, %rsi
    movq       $1024, %rdx
    movq       $0x01, %r10
    syscall
    movq        %rax, (%rbp)

    # exit(0)
    movq $60, %rax
    movq  $0, %rdi
    syscall

    .data
