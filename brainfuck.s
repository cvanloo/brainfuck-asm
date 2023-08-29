    .globl _start
    .text

CHUNK_SIZE = 512

_start:
# *** GET COMMAND LINE ARGUMENTS ***
    movq   (%rsp), %rax # argc
    #movq  8(%rsp), %rdi # argv[0]
    movq 16(%rsp), %rsi # argv[1]

# *** SETUP STACK ***
    movq %rsp, %rbp
    subq $124, %rsp
    #   rbp-8 = program ptr (null terminated)
    #  rbp-16 = program len, then loop mapping ptr
    #  rbp-24 = input ptr (null terminated)
    # rbp-124 = registers for brainfuck program

    movq %rsi, -24(%rbp) # save pointer to user input on stack

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

    testq %rax, %rax
    jz read_input_end

    addq %rax, %r13 # update amount of bytes read

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

    movq  %r12, -8(%rbp)  # program ptr
    movq  %r13, -16(%rbp) # program len

    movq $0, (%r12,%r13,1) # null-terminate program

# *** PRE-PROCESS LOOPS ***

    # stack space needed:   program len * 8 for loop mapping
    #                     + program len / 2 * 8 for temporary loop stack
    #   multiply by 8 because *one* pointer is 8 bytes!
    movq %r13, %r8
    shlq   $3, %r8 # r8 = program len * 8

    movq  %r8, %rax
    shrq   $1, %rax # / 2
    addq  %r8, %rax
    subq %rax, %rsp # extend stack frame

    # rbp-124-prog_len*8       = loop mapping
    # rbp-124-prog_len*8-r13*4 = loop stack
    # also:
    # rbp-124-r8       = loop mapping
    # rbp-124-r8-r13*4 = loop stack

    movq %r12, %rax # rax = ptr to current program char

    leaq -124(%rbp), %rdx
    subq        %r8, %rdx
    movq       %rdx, %rsi # rsi = ptr to loop mapping
    shrq         $1, %r8
    subq        %r8, %rdx # rdx = ptr to top of loop stack

    movq %rsi, -16(%rbp)  # save pointer to loop mapping on stack

preprocess_loops:
    movq (%rax), %r8
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
    movq %rax, %r9
    subq %r12, %r9 # r9 = index key for loop mapping
    movq  %r8, (%rsi, %r9, 8)

    # map start -> end
    movq  %r8, %r9
    subq %r12, %r9
    movq %rax, (%rsi, %r9, 8)

    # fall through into preprocess_loops_next

preprocess_loops_next:
    incq   %rax
    movq (%rax), %rbx
    testb   %bl, %bl
    jnz preprocess_loops

# *** INTERPRET BRAINFUCK CODE ***

    movq   -8(%rbp), %r11 # pc
    movq  -16(%rbp), %r15 # loop mapping
    movq  -24(%rbp), %r13 # input str
    leaq -124(%rbp), %r14 # registers

interpret_instruction:
    mov (%r11), %rax
    cmpb $'+, %al
    je val_inc
    cmpb $'-, %al
    je val_dec
    cmpb $'>, %al
    je ptr_inc
    cmpb $'<, %al
    je ptr_dec
    cmpb $'[, %al
    je cond_start
    cmpb $'], %al
    je cond_end
    cmpb $',, %al
    je io_in
    cmpb $'., %al
    je io_out
    jmp interpret_instruction_next # anything else counts as comments

ptr_inc:
    incq %r14
    jmp interpret_instruction_next

ptr_dec:
    decq %r14
    jmp interpret_instruction_next

val_inc:
    incb (%r14)
    jmp interpret_instruction_next

val_dec:
    decb (%r14)
    jmp interpret_instruction_next

cond_start:
    # jump if (%r14) == 0
    movq (%r14), %rax
    testb   %al, %al
    jnz interpret_instruction_next

    lea -8(%rbp), %rax
    movq    %r11, %rdi
    subq    %rax, %rdi           # rdi = index into loop mapping
    movq   (%r15, %rdi, 8), %r11 # set pc to cond end

    jmp interpret_instruction_next

cond_end:
    # jump if (%r14) != 0
    movq (%r14), %rax
    cmpb     $0, %al
    jle interpret_instruction_next

    movq -8(%rbp), %rax
    leaq   (%r11), %rdi
    subq     %rax, %rdi           # rdi = index into loop mapping
    movq    (%r15, %rdi, 8), %r11 # set pc to cond start

    jmp interpret_instruction_next

io_in:
    movq (%r13), %rax
    cmpb     $0, %al
    jg io_in_set

    movb $-1, (%r14)
    jmp interpret_instruction_next

io_in_set:
    movb %al, (%r14)
    incq %r13

    jmp interpret_instruction_next

io_out:
    pushq %r11

    # write(stdout, register, count=1)
    movq   $1, %rax
    movq   $1, %rdi
    movq %r14, %rsi
    movq   $1, %rdx
    syscall

    popq %r11

    # fallthrough into interpret_instruction_next

interpret_instruction_next:
    incq   %r11
    movq (%r11), %rax
    testb   %al, %al
    jnz interpret_instruction

    # exit(0)
    movq $60, %rax
    movq  $0, %rdi
    syscall

    .data

ask_for_input: .ascii "Input program > "
ask_for_input_len = . - ask_for_input
