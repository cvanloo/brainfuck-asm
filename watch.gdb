starti < echo.bf "Input"
display/s $r11
display/s $r13
display/xb $r14
display (char*) $r14
display *(char* (*)[16]) $r15
b interpret_instruction
