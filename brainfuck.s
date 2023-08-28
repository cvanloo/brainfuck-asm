    .globl _start
    .text

CHUNK_SIZE = 512

_start:
    movq %rsp, %rbp
    subq  $16, %rsp
    # rbp-0 = input ptr
    # rbp-8 = input len

# *** READ USER INPUT ***

    # mmap(addr=0, len=input_len, prot=READ|WRITE, flags=PRIVATE|ANONYMOUS, fildes=-1, off=0)
    movq          $9, %rax
    movq          $0, %rdi
    movq $CHUNK_SIZE, %rsi
    movq       $0x03, %rdx
    movq       $0x22, %r10
    movq         $-1, %r8
    movq          $0, %r9
    syscall

    movq %rax, %r12 # r12: ptr to input buf
    xorq %r13, %r13 # r13: amount of bytes read

read_input:
    # read(stdin, buf, count=input len)
    xorq        %rax, %rax
    xorq        %rdi, %rdi
    movq        %r12, %rsi # buf begin
    addq        %r13, %rsi #           + offset
    movq $CHUNK_SIZE, %rdx
    syscall

    addq %rax, %r13 # update amount of bytes read

    cmpq $CHUNK_SIZE, %rax
    jl read_input_end

    # mremap(buf, old len, new len, flags=MAYMOVE) -- allocate another chunk
    movq         $25, %rax
    movq        %r12, %rdi
    movq        %r13, %rsi
    movq        %r13, %rdx # old size
    addq $CHUNK_SIZE, %rdx #          + chunk size
    movq       $0x01, %r10
    syscall

    movq %rax, %r12 # buf may have been moved to different address
    jmp read_input

read_input_end:

    movq  %r12, (%rbp)   # input ptr
    movq  %r13, -8(%rbp) # input len

    # write(stdout, & input len, count=8)
    movq      $1, %rax
    movq      $1, %rdi
    lea -8(%rbp), %rsi
    movq      $8, %rdx
    syscall

    # exit(0)
    movq $60, %rax
    movq  $0, %rdi
    syscall

    .data
