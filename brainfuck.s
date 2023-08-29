    .globl _start
    .text

CHUNK_SIZE = 512

_start:
# *** SETUP STACK ***
    movq %rsp, %rbp
    subq  $16, %rsp
    # rbp-0 = input ptr
    # rbp-8 = input len

# *** ASK FOR USER INPUT ***

    # write(stdout, "Input program > ", len(...))
    movq                 $1, %rax
    movq                 $1, %rdi
    movq     $ask_for_input, %rsi
    movq $ask_for_input_len, %rdx
    syscall

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

    movq %rax, %r12 # r12 = ptr to input buf
    xorq %r13, %r13 # r13 = amount of bytes read

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

# *** PRE-PROCESS LOOPS ***

    # stack space needed:   program len for loop mapping
    #                     + program len / 2 * 8 for temporary loop stack
    movq %r13, %rax
    shlq   $2, %rax # / 2 * 8 <=> * 4
    addq %r13, %rax
    subq %rax, %rsp
    # rbp-16     = loop mapping
    # rbp-16-r13 = loop stack

    movq %r12, %rax # rax = ptr to current input char
    movq %r13, %rdi # rdi = number of iterations left

    leaq -16(%rbp), %rdx
    movq      %rdx, %rsi # rsi = ptr to loop mapping
    subq      %r13, %rdx # rdx = ptr to top of loop stack

preprocess_loops:
    movq (%rax), %r8
    movzx  %r8b, %r8
    cmpb    $'[, %r8b # $'[ = 0x5B
    je push_loop_start
    cmpb    $'], %r8b # $'] = 0x5D
    je create_loop_mapping
    jmp preprocess_loops_next

push_loop_start:
    movq %rax, (%rdx)
    addq   $8, %rdx

    jmp preprocess_loops_next

create_loop_mapping:
    subq     $8, %rdx
    movq (%rdx), %r8 #  r8 = address of loop start
                     # rax = address of loop end

    # map end -> start
    movq  %rax, %r9
    subq  %r12, %r9 # r9 = index key for loop mapping
    addq  %rsi, %r9 # index into loop map
    movq   %r8, (%r9) # store mapping

    # map start -> end
    movq   %r8, %r9
    subq  %r12, %r9
    addq  %rsi, %r9
    movq  %rax, (%r9)

    # fall through into preprocess_loops_next

preprocess_loops_next:
    incq  %rax
    decq  %rdi
    testq %rdi, %rdi
    jnz preprocess_loops


    # exit(0)
    movq $60, %rax
    movq  $0, %rdi
    syscall

    .data

ask_for_input: .ascii "Input program > "
ask_for_input_len = . - ask_for_input
