starti < echo.bf "Input"
display *(char* (*)[16]) $rsi
display (int) $r13
display (char*) $rax
display *(char**) $rdx
display *(char**) ($rdx-8)
display *(char**) ($rbp-8)
b preprocess_loops
